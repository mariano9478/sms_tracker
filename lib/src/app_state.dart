import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'command_catalog.dart';
import 'location_resolver.dart';
import 'models.dart';
import 'response_parser.dart';
import 'sms_channel.dart';

/// Estado central de la app: configuración del rastreador, historial de
/// mensajes, información parseada (batería/ubicación) y contactos SOS.
class AppState extends ChangeNotifier {
  static const _kTrackerNumber = 'tracker_number';
  static const _kTrackerName = 'tracker_name';
  static const _kSentLog = 'sent_log';
  static const _kContacts = 'contacts';
  static const _kResolvedCoords = 'resolved_locations';
  static const _kSosDismissed = 'sos_dismissed_key';
  static const _kContactsSyncedAt = 'contacts_synced_at';
  static const _kContactsSyncAttempt = 'contacts_sync_attempt';
  static const _maxSentLog = 300;
  static const _maxResolvedCache = 50;

  /// Antigüedad máxima de los contactos sincronizados antes de volver a
  /// consultar automáticamente al dispositivo con `A?`.
  static const contactsMaxAge = Duration(days: 30);

  bool initialized = false;
  bool permissionsGranted = false;

  String? trackerNumber;
  String trackerName = 'Mi rastreador';

  /// Historial completo (enviados + recibidos), ordenado por fecha asc.
  List<SmsRecord> records = [];

  /// Contactos SOS conocidos (guardados localmente y/o parseados de `A?`).
  List<SosContact> contacts = [];

  /// Fecha de la última respuesta `A?` del dispositivo (sincronización
  /// real de contactos). `null` si nunca respondió.
  DateTime? contactsSyncedAt;

  int? batteryPercent;
  DateTime? batteryReportedAt;
  TrackerLocation? lastLocation;

  /// `true` mientras se están obteniendo las coordenadas del link de
  /// ubicación (siguiendo su redirección a Google Maps).
  bool resolvingLocation = false;

  /// Mensaje de emergencia (botón SOS) activo, aún no descartado por el
  /// usuario. Mientras no sea null la UI muestra la alerta a pantalla
  /// completa.
  SmsRecord? activeSosRecord;

  /// Hora de activación reportada en el mensaje de SOS ("Alarm Time").
  DateTime? sosAlarmTime;

  String? _dismissedSosKey;

  /// Vista que la UI debe mostrar (por ej. al tocar una notificación):
  /// 'map', 'messages'… La consume [HomeShell] y la vuelve a null.
  final ValueNotifier<String?> viewRequest = ValueNotifier<String?>(null);

  StreamSubscription<Map<String, dynamic>>? _incomingSub;
  List<SmsRecord> _sentLog = [];

  /// Caché url → [lat, lng] de links ya resueltos, persistida.
  Map<String, List<double>> _resolvedCoords = {};
  String? _resolvingUrl;

  bool get isConfigured =>
      trackerNumber != null && trackerNumber!.trim().isNotEmpty;

  Future<void> init() async {
    trackerNumber = await SmsChannel.getPref(_kTrackerNumber);
    trackerName = await SmsChannel.getPref(_kTrackerName) ?? 'Mi rastreador';
    _sentLog = _decodeRecords(await SmsChannel.getPref(_kSentLog));
    contacts = _decodeContacts(await SmsChannel.getPref(_kContacts));
    _resolvedCoords =
        _decodeResolved(await SmsChannel.getPref(_kResolvedCoords));
    _dismissedSosKey = await SmsChannel.getPref(_kSosDismissed);
    final syncedRaw = await SmsChannel.getPref(_kContactsSyncedAt);
    contactsSyncedAt = syncedRaw == null ? null : DateTime.tryParse(syncedRaw);
    permissionsGranted = await SmsChannel.hasPermissions();
    if (permissionsGranted && isConfigured) {
      await refreshInbox();
      _listenIncoming();
      unawaited(_maybeAutoSyncContacts());
    }
    // Navegación desde notificaciones: app ya corriendo (handler) o
    // recién abierta desde la notificación (consumeLaunchView).
    SmsChannel.setLaunchViewHandler((view) => viewRequest.value = view);
    final launchView = await SmsChannel.consumeLaunchView();
    if (launchView != null) viewRequest.value = launchView;
    initialized = true;
    notifyListeners();
  }

  Future<bool> requestPermissions() async {
    permissionsGranted = await SmsChannel.requestPermissions();
    if (permissionsGranted && isConfigured) {
      await refreshInbox();
      _listenIncoming();
    }
    notifyListeners();
    return permissionsGranted;
  }

  Future<void> saveTracker({required String number, required String name}) async {
    trackerNumber = number.trim();
    trackerName = name.trim().isEmpty ? 'Mi rastreador' : name.trim();
    await SmsChannel.setPref(_kTrackerNumber, trackerNumber);
    await SmsChannel.setPref(_kTrackerName, trackerName);
    if (permissionsGranted && isConfigured) {
      await refreshInbox();
      _listenIncoming();
    }
    notifyListeners();
  }

  /// Envía un comando SMS al rastreador y lo registra en el historial.
  Future<String?> sendCommand(String command) async {
    final number = trackerNumber;
    if (number == null || number.isEmpty) {
      return 'Configurá primero el número del rastreador.';
    }
    if (!permissionsGranted) {
      return 'La app no tiene permisos de SMS. Otorgalos en Ajustes.';
    }
    try {
      await SmsChannel.sendSms(to: number, body: command);
    } catch (e) {
      return 'No se pudo enviar el SMS: $e';
    }
    final record = SmsRecord(
      body: command,
      date: DateTime.now(),
      incoming: false,
    );
    _sentLog.add(record);
    if (_sentLog.length > _maxSentLog) {
      _sentLog = _sentLog.sublist(_sentLog.length - _maxSentLog);
    }
    unawaited(SmsChannel.setPref(_kSentLog, _encodeRecords(_sentLog)));
    _mergeRecords(inbox: null);
    notifyListeners();
    return null; // sin error
  }

  /// Relee la bandeja de entrada del sistema (mensajes del rastreador).
  Future<void> refreshInbox() async {
    if (!permissionsGranted || !isConfigured) return;
    List<Map<String, dynamic>> inbox;
    try {
      inbox = await SmsChannel.queryInbox(suffix: _trackerSuffix());
    } catch (_) {
      return;
    }
    final incoming = inbox
        .map((m) => SmsRecord(
              body: m['body'] as String? ?? '',
              date: DateTime.fromMillisecondsSinceEpoch(
                  (m['date'] as num?)?.toInt() ?? 0),
              incoming: true,
            ))
        .toList();
    _mergeRecords(inbox: incoming);
    _reparseAll();
    notifyListeners();
  }

  /// Guarda un contacto en la lista local (lo que hay en el dispositivo
  /// se sincroniza enviando el comando correspondiente).
  Future<void> saveContactLocally(SosContact contact) async {
    contacts.removeWhere((c) => c.slot == contact.slot);
    contacts.add(contact);
    contacts.sort((a, b) => a.slot.compareTo(b.slot));
    await SmsChannel.setPref(_kContacts, _encodeContacts(contacts));
    notifyListeners();
  }

  Future<void> removeContactLocally(int slot) async {
    contacts.removeWhere((c) => c.slot == slot);
    await SmsChannel.setPref(_kContacts, _encodeContacts(contacts));
    notifyListeners();
  }

  Future<void> openMap() async {
    final location = lastLocation;
    if (location == null) return;
    try {
      await SmsChannel.openUrl(location.openUrl);
    } catch (_) {
      // Sin app capaz de abrir el link; se ignora.
    }
  }

  // ── Internos ─────────────────────────────────────────────────────────

  String _trackerSuffix() {
    final digits = (trackerNumber ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 8) return digits;
    return digits.substring(digits.length - 8);
  }

  void _listenIncoming() {
    _incomingSub ??= SmsChannel.incomingSms().listen((event) {
      final address = event['address'] as String? ?? '';
      final digits = address.replaceAll(RegExp(r'\D'), '');
      final suffix = _trackerSuffix();
      if (suffix.isEmpty || !digits.endsWith(suffix)) return;
      // La fuente de verdad es la bandeja del sistema: se relee para
      // evitar duplicados entre el broadcast y el proveedor de SMS.
      refreshInbox();
    });
  }

  List<SmsRecord> _lastInbox = [];

  void _mergeRecords({List<SmsRecord>? inbox}) {
    if (inbox != null) _lastInbox = inbox;
    final seen = <String>{};
    final merged = <SmsRecord>[];
    for (final r in [..._lastInbox, ..._sentLog]) {
      if (seen.add(r.dedupeKey)) merged.add(r);
    }
    merged.sort((a, b) => a.date.compareTo(b.date));
    records = merged;
  }

  void _reparseAll() {
    int? battery;
    DateTime? batteryAt;
    TrackerLocation? location;
    SmsRecord? latestSos;
    DateTime? contactsReportedAt;
    final deviceContacts = <int, SosContact>{};

    for (final r in records) {
      if (!r.incoming) continue;
      final b = ResponseParser.parseBattery(r.body);
      if (b != null) {
        battery = b;
        batteryAt = r.date;
      }
      final loc = ResponseParser.parseLocation(r.body, r.date);
      if (loc != null) location = loc;
      if (ResponseParser.isSosAlert(r.body)) latestSos = r;
      final parsedContacts = ResponseParser.parseContacts(r.body);
      if (parsedContacts.isNotEmpty) contactsReportedAt = r.date;
      for (final c in parsedContacts) {
        deviceContacts[c.slot] = c;
      }
    }

    // Alerta SOS: se muestra la más reciente mientras no haya sido
    // descartada explícitamente por el usuario.
    if (latestSos != null && latestSos.dedupeKey != _dismissedSosKey) {
      activeSosRecord = latestSos;
      sosAlarmTime = ResponseParser.parseAlarmTime(latestSos.body);
    } else {
      activeSosRecord = null;
      sosAlarmTime = null;
    }

    batteryPercent = battery;
    batteryReportedAt = batteryAt;
    lastLocation = _withResolvedCoords(location);

    // Link sin coordenadas: se resuelve en segundo plano siguiendo la
    // redirección a Google Maps para poder mostrarlo en el mapa integrado.
    final pending = lastLocation;
    if (pending != null && !pending.hasCoordinates && pending.mapUrl != null) {
      unawaited(_resolveLocation(pending));
    }

    if (deviceContacts.isNotEmpty) {
      // Lo reportado por el dispositivo pisa la copia local.
      for (final c in deviceContacts.values) {
        contacts.removeWhere((e) => e.slot == c.slot);
        contacts.add(c);
      }
      contacts.sort((a, b) => a.slot.compareTo(b.slot));
      unawaited(SmsChannel.setPref(_kContacts, _encodeContacts(contacts)));
      if (contactsReportedAt != null &&
          (contactsSyncedAt == null ||
              contactsReportedAt.isAfter(contactsSyncedAt!))) {
        contactsSyncedAt = contactsReportedAt;
        unawaited(SmsChannel.setPref(
            _kContactsSyncedAt, contactsReportedAt.toIso8601String()));
      }
    }
  }

  /// Consulta `A?` automáticamente si la última sincronización de
  /// contactos tiene más de [contactsMaxAge] (con un reintento diario
  /// como máximo, para no gastar SMS si el dispositivo no responde).
  Future<void> _maybeAutoSyncContacts() async {
    if (!permissionsGranted || !isConfigured) return;
    final now = DateTime.now();
    if (contactsSyncedAt != null &&
        now.difference(contactsSyncedAt!) < contactsMaxAge) {
      return;
    }
    final attemptRaw = await SmsChannel.getPref(_kContactsSyncAttempt);
    final lastAttempt = attemptRaw == null ? null : DateTime.tryParse(attemptRaw);
    if (lastAttempt != null &&
        now.difference(lastAttempt) < const Duration(days: 1)) {
      return;
    }
    await SmsChannel.setPref(_kContactsSyncAttempt, now.toIso8601String());
    await sendCommand(TrackerCommands.viewContacts);
  }

  /// Envía [message] por SMS a cada número de [numbers] (aviso manual de
  /// urgencia a los contactos de emergencia). Devuelve cuántos salieron.
  Future<int> sendUrgencyMessage({
    required List<String> numbers,
    required String message,
  }) async {
    if (!permissionsGranted) return 0;
    var sent = 0;
    for (final number in numbers) {
      try {
        await SmsChannel.sendSms(to: number, body: message);
        sent++;
      } catch (_) {
        // Se sigue con el resto de los contactos.
      }
    }
    return sent;
  }

  /// Abre WhatsApp con el chat de [number] y [message] ya escrito.
  /// Requiere que el número incluya código de país para que WhatsApp lo
  /// resuelva (ej: 54911...).
  Future<void> openWhatsApp({
    required String number,
    required String message,
  }) async {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final url = 'https://wa.me/$digits?text=${Uri.encodeComponent(message)}';
    try {
      await SmsChannel.openUrl(url);
    } catch (_) {
      // WhatsApp no disponible; se ignora.
    }
  }

  /// Completa las coordenadas desde la caché si el link ya fue resuelto.
  TrackerLocation? _withResolvedCoords(TrackerLocation? location) {
    if (location == null || location.hasCoordinates) return location;
    final cached = _resolvedCoords[location.mapUrl];
    if (cached == null || cached.length != 2) return location;
    return TrackerLocation(
      latitude: cached[0],
      longitude: cached[1],
      mapUrl: location.mapUrl,
      deviceTime: location.deviceTime,
      reportedAt: location.reportedAt,
    );
  }

  Future<void> _resolveLocation(TrackerLocation location) async {
    final url = location.mapUrl;
    if (url == null || _resolvingUrl == url) return;
    _resolvingUrl = url;
    resolvingLocation = true;
    notifyListeners();

    final coords = await LocationResolver.resolve(location.openUrl);

    _resolvingUrl = null;
    resolvingLocation = false;
    if (coords != null) {
      if (_resolvedCoords.length >= _maxResolvedCache) {
        _resolvedCoords = {};
      }
      _resolvedCoords[url] = [coords.lat, coords.lng];
      unawaited(
          SmsChannel.setPref(_kResolvedCoords, jsonEncode(_resolvedCoords)));
      if (lastLocation?.mapUrl == url) {
        lastLocation = _withResolvedCoords(lastLocation);
      }
    }
    notifyListeners();
  }

  /// Descarta la alerta SOS activa (no volverá a mostrarse para ese
  /// mismo mensaje).
  Future<void> dismissSosAlert() async {
    final record = activeSosRecord;
    if (record == null) return;
    _dismissedSosKey = record.dedupeKey;
    activeSosRecord = null;
    sosAlarmTime = null;
    await SmsChannel.setPref(_kSosDismissed, _dismissedSosKey);
    notifyListeners();
  }

  /// Abre la app de Mensajes del sistema con el número del rastreador y
  /// [body] ya escrito — plan B para operar el dispositivo sin esta app.
  Future<void> openSmsComposer([String body = '']) async {
    final number = trackerNumber;
    if (number == null || number.isEmpty) return;
    try {
      await SmsChannel.openSmsComposer(to: number, body: body);
    } catch (_) {
      // Sin app de mensajes; se ignora.
    }
  }

  /// Abre el discador con el número del rastreador (para llamarlo y
  /// escuchar qué pasa; el dispositivo atiende automáticamente si tiene
  /// respuesta automática configurada).
  Future<void> callTracker() async {
    final number = trackerNumber;
    if (number == null || number.isEmpty) return;
    try {
      await SmsChannel.openUrl('tel:$number');
    } catch (_) {
      // Sin app de teléfono; se ignora.
    }
  }

  /// Reintenta obtener las coordenadas del link de la última ubicación.
  Future<void> retryResolveLocation() async {
    final location = lastLocation;
    if (location != null && !location.hasCoordinates) {
      await _resolveLocation(location);
    }
  }

  Map<String, List<double>> _decodeResolved(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((key, value) => MapEntry(
            key,
            (value as List<dynamic>)
                .map((e) => (e as num).toDouble())
                .toList(),
          ));
    } catch (_) {
      return {};
    }
  }

  String _encodeRecords(List<SmsRecord> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  List<SmsRecord> _decodeRecords(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(SmsRecord.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _encodeContacts(List<SosContact> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  List<SosContact> _decodeContacts(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(SosContact.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    viewRequest.dispose();
    super.dispose();
  }
}
