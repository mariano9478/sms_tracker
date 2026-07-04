/// Catálogo de comandos SMS de los rastreadores EV07BG (2G) / BX (4G).
///
/// Fuente: "Guía de Comandos SMS - Dispositivo SOS (Modelos EV07BG / BX)".
/// Todas las funciones son puras: reciben parámetros y devuelven el texto
/// exacto que hay que enviar por SMS al número del chip del rastreador.
class TrackerCommands {
  TrackerCommands._();

  // ── 1. Gestión de contactos (SOS) ────────────────────────────────────

  /// `A(n),(SMS 1/0),(LLAMADA 1/0),(número)` — ej: `A1,1,1,1138889888`
  static String addContact({
    required int slot,
    required bool sms,
    required bool call,
    required String number,
  }) =>
      'A$slot,${sms ? 1 : 0},${call ? 1 : 0},$number';

  /// Consulta los contactos configurados en el dispositivo.
  static const String viewContacts = 'A?';

  /// `removeA(n)` — ej: `removeA3`
  static String removeContact(int slot) => 'removeA$slot';

  // ── 2. Botón lateral ─────────────────────────────────────────────────

  /// `X(n)` — el botón lateral llama al contacto n. Ej: `X1`
  static String sideButton(int slot) => 'X$slot';

  /// Deshabilita el botón lateral.
  static const String sideButtonOff = 'XO';

  // ── 3. Sensores y alarmas ────────────────────────────────────────────

  /// `FL(on),(sensibilidad 1-9),(llamada 1/0)` — ej: `FL1,5,1`
  static String fallSensor({required int sensitivity, required bool call}) =>
      'FL1,$sensitivity,${call ? 1 : 0}';

  /// Desactiva el sensor de caída.
  static const String fallSensorOff = 'FLO';

  /// `GE0(n),1,0,(metros)M` — ej: `GE01,1,0,100M`
  static String geofence({int slot = 1, required int meters}) =>
      'GE0$slot,1,0,${meters}M';

  /// `NMO(on),(tiempo)M,(llamada 1/0)` — ej: `NMO1,80M,1`
  static String noMovement({required int minutes, required bool call}) =>
      'NMO1,${minutes}M,${call ? 1 : 0}';

  /// Desactiva la alerta de no movimiento.
  static const String noMovementOff = 'NMOO';

  // ── 4. Consultas y estado ────────────────────────────────────────────

  /// Pide la ubicación actual (responde con link a mapa / coordenadas).
  static const String locate = 'loc';

  /// Pide el porcentaje de batería.
  static const String battery = 'Battery';

  /// Pide el resumen de configuración.
  static const String status = 'Status';

  /// Hace sonar el dispositivo ("Acá estoy").
  static const String findMe = 'Findme';

  // ── 5. Configuración avanzada y audio ────────────────────────────────

  /// Activa la escucha remota (micrófono silencioso).
  static const String remoteListenOn = 'LT1';

  /// Desactiva la escucha remota.
  static const String remoteListenOff = 'LTO';

  /// `$rt(0-100)$` — ej: `$rt50$`
  static String ringVolume(int volume) => '\$rt$volume\$';

  /// `micvolume(0-15)` — ej: `micvolume10`
  static String micVolume(int volume) => 'micvolume$volume';

  /// `TZ(offset)` — ej: `TZ-03`
  static String timeZone(int offset) {
    final abs = offset.abs().toString().padLeft(2, '0');
    return offset < 0 ? 'TZ-$abs' : 'TZ$abs';
  }

  /// `Low1,(porcentaje)` — alerta automática de batería baja.
  /// Ej: `Low1,20` (valor de fábrica: 20%).
  static String lowBatteryAlert(int percent) => 'Low1,$percent';
}
