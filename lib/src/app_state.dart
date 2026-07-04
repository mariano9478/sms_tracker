import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

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
  static const _maxSentLog = 300;

  bool initialized = false;
  bool permissionsGranted = false;

  String? trackerNumber;
  String trackerName = 'Mi rastreador';

  /// Historial completo (enviados + recibidos), ordenado por fecha asc.
  List<SmsRecord> records = [];

  /// Contactos SOS conocidos (guardados localmente y/o parseados de `A?`).
  List<SosContact> contacts = [];

  int? batteryPercent;
  DateTime? batteryReportedAt;
  TrackerLocation? lastLocation;

  /// Vista que la UI debe mostrar (por ej. al tocar una notificación):
  /// 'map', 'messages'… La consume [HomeShell] y la vuelve a null.
  final ValueNotifier<String?> viewRequest = ValueNotifier<String?>(null);

  StreamSubscription<Map<String, dynamic>>? _incomingSub;
  List<SmsRecord> _sentLog = [];

  bool get isConfigured =>
      trackerNumber != null && trackerNumber!.trim().isNotEmpty;

  Future<void> init() async {
    trackerNumber = await SmsChannel.getPref(_kTrackerNumber);
    trackerName = await SmsChannel.getPref(_kTrackerName) ?? 'Mi rastreador';
    _sentLog = _decodeRecords(await SmsChannel.getPref(_kSentLog));
    contacts = _decodeContacts(await SmsChannel.getPref(_kContacts));
    permissionsGranted = await SmsChannel.hasPermissions();
    if (permissionsGranted && isConfigured) {
      await refreshInbox();
      _listenIncoming();
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
      for (final c in ResponseParser.parseContacts(r.body)) {
        deviceContacts[c.slot] = c;
      }
    }

    batteryPercent = battery;
    batteryReportedAt = batteryAt;
    lastLocation = location;

    if (deviceContacts.isNotEmpty) {
      // Lo reportado por el dispositivo pisa la copia local.
      for (final c in deviceContacts.values) {
        contacts.removeWhere((e) => e.slot == c.slot);
        contacts.add(c);
      }
      contacts.sort((a, b) => a.slot.compareTo(b.slot));
      unawaited(SmsChannel.setPref(_kContacts, _encodeContacts(contacts)));
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
