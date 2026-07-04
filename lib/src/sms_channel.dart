import 'package:flutter/services.dart';

/// Puente hacia el código nativo Android (ver `MainActivity.kt`).
///
/// No se usan plugins de terceros: enviar/leer/recibir SMS, preferencias
/// y apertura de URLs se resuelven con canales de plataforma propios.
class SmsChannel {
  SmsChannel._();

  static const MethodChannel _methods = MethodChannel('sms_tracker/methods');
  static const EventChannel _incoming = EventChannel('sms_tracker/incoming');

  static Stream<Map<String, dynamic>>? _incomingStream;

  static Future<bool> hasPermissions() async {
    return await _methods.invokeMethod<bool>('hasPermissions') ?? false;
  }

  /// Vista pedida por la notificación que abrió la app (arranque en frío),
  /// o `null`. Se consume: la segunda llamada devuelve `null`.
  static Future<String?> consumeLaunchView() {
    return _methods.invokeMethod<String>('consumeLaunchView');
  }

  /// Registra el callback para cuando el usuario toca una notificación con
  /// la app ya corriendo (el nativo invoca `launchView`).
  static void setLaunchViewHandler(void Function(String view) handler) {
    _methods.setMethodCallHandler((call) async {
      if (call.method == 'launchView') {
        final view = call.arguments as String?;
        if (view != null) handler(view);
      }
      return null;
    });
  }

  static Future<bool> requestPermissions() async {
    return await _methods.invokeMethod<bool>('requestPermissions') ?? false;
  }

  static Future<void> sendSms({required String to, required String body}) {
    return _methods.invokeMethod('sendSms', {'to': to, 'body': body});
  }

  /// Lee la bandeja de entrada del sistema, filtrada por los últimos
  /// dígitos del remitente ([suffix]).
  static Future<List<Map<String, dynamic>>> queryInbox({
    required String suffix,
    int limit = 300,
  }) async {
    final raw = await _methods.invokeMethod<List<dynamic>>(
      'queryInbox',
      {'suffix': suffix, 'limit': limit},
    );
    if (raw == null) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  static Future<void> openUrl(String url) {
    return _methods.invokeMethod('openUrl', {'url': url});
  }

  /// Abre la app de Mensajes del sistema con el destinatario y el texto
  /// ya escritos (el usuario solo tiene que tocar enviar).
  static Future<void> openSmsComposer({
    required String to,
    String body = '',
  }) {
    return _methods.invokeMethod('openSmsComposer', {'to': to, 'body': body});
  }

  static Future<String?> getPref(String key) {
    return _methods.invokeMethod<String>('getPref', {'key': key});
  }

  static Future<void> setPref(String key, String? value) {
    return _methods.invokeMethod('setPref', {'key': key, 'value': value});
  }

  /// SMS entrantes en vivo mientras la app está abierta.
  static Stream<Map<String, dynamic>> incomingSms() {
    _incomingStream ??= _incoming.receiveBroadcastStream().map((event) {
      final map = event as Map<dynamic, dynamic>;
      return map.map((k, v) => MapEntry(k.toString(), v));
    }).asBroadcastStream();
    return _incomingStream!;
  }
}
