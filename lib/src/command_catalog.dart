/// Catálogo de comandos SMS de los rastreadores EV07BG (2G) / BX (4G).
///
/// Fuente: "Guía Rápida de Uso — Dispositivo SOS con GPS, Modelos EV07BG
/// (2G) / BX (4G)" v1.5 (Tech Future S.R.L.).
///
/// Todas las funciones son puras: reciben parámetros y devuelven el texto
/// exacto que hay que enviar por SMS al número del chip del rastreador.
/// Ojo: los comandos de apagado usan CERO (X0, FL0, NMO0, LT0), no la
/// letra O.
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

  /// Secuencia de llamadas SOS cuando un contacto atiende:
  /// `SCS0` continúa llamando al resto (valor de fábrica),
  /// `SCS1` interrumpe la secuencia (sugerido por el fabricante).
  static String callSequence({required bool interrupt}) =>
      interrupt ? 'SCS1' : 'SCS0';

  // ── 2. Botón lateral ─────────────────────────────────────────────────

  /// `X(n)` — el botón lateral llama al contacto n. Ej: `X1`.
  /// De fábrica viene configurado para llamar al 2do contacto (X2).
  static String sideButton(int slot) => 'X$slot';

  /// Deshabilita el botón lateral (X seguido de CERO).
  static const String sideButtonOff = 'X0';

  // ── 3. Sensores y alarmas ────────────────────────────────────────────

  /// `FL(on),(sensibilidad 1-9),(llamada 1/0)` — ej: `FL1,5,1`
  /// (valor de fábrica: sensibilidad 5 con llamada).
  static String fallSensor({required int sensitivity, required bool call}) =>
      'FL1,$sensitivity,${call ? 1 : 0}';

  /// Desactiva el sensor de caída (FL + CERO).
  static const String fallSensorOff = 'FL0';

  /// `GEO(n),1,0,(metros)M` — ej: `GEO1,1,0,100M`. Hay 2 cercos (GEO1 y
  /// GEO2). El dispositivo debe estar en el lugar a monitorear al
  /// configurarlo.
  static String geofence({int slot = 1, required int meters}) =>
      'GEO$slot,1,0,${meters}M';

  /// `NMO(on),(tiempo)(S|M|H),(llamada 1/0)` — ej: `NMO1,80M,1`,
  /// `NMO1,10H,0`. Rango máximo: 36000s, 600m o 10h.
  static String noMovement({
    required int amount,
    String unit = 'M',
    required bool call,
  }) =>
      'NMO1,$amount$unit,${call ? 1 : 0}';

  /// Desactiva la alerta de no movimiento (NMO + CERO).
  static const String noMovementOff = 'NMO0';

  // ── 4. Consultas y estado ────────────────────────────────────────────

  /// Pide la ubicación actual (responde con link de Google Maps).
  static const String locate = 'loc';

  /// Pide el porcentaje de batería.
  static const String battery = 'Battery';

  /// Pide el resumen de configuración.
  static const String status = 'Status';

  /// Hace sonar el dispositivo ("Acá estoy") hasta presionar SOS.
  static const String findMe = 'Findme';

  // ── 5. Audio y escucha ───────────────────────────────────────────────

  /// Activa la escucha remota: enviar antes de llamar al dispositivo,
  /// que atenderá en modo silencioso.
  static const String remoteListenOn = 'LT1';

  /// Desactiva la escucha remota (LT + CERO).
  static const String remoteListenOff = 'LT0';

  /// `rt(0-100)` — volumen del timbre. Ej: `rt50` (fábrica: 70).
  static String ringVolume(int volume) => 'rt$volume';

  /// `micvolume(0-15)` — volumen del micrófono. Ej: `micvolume10`
  /// (fábrica: 8).
  static String micVolume(int volume) => 'micvolume$volume';

  /// `speakervolume(0-100)` — volumen del parlante. Ej: `speakervolume90`
  /// (fábrica: 80).
  static String speakerVolume(int volume) => 'speakervolume$volume';

  /// Parlante durante llamadas SOS: `sosspeaker1` ON / `sosspeaker0` OFF
  /// (el fabricante sugiere OFF).
  static String sosSpeaker({required bool on}) => 'sosspeaker${on ? 1 : 0}';

  /// Voces/beeps del dispositivo: `beep1` deja las voces de fábrica,
  /// `beep0` las elimina.
  static String beepVoices({required bool on}) => 'beep${on ? 1 : 0}';

  // ── 6. Sistema ───────────────────────────────────────────────────────

  /// Llamadas entrantes: `callin1` acepta todas, `callin0` solo de los
  /// contactos de emergencia (lista blanca).
  static String callIn({required bool all}) => 'callin${all ? 1 : 0}';

  /// `Prefix1,(nombre)` — asigna un nombre al dispositivo (aparece en
  /// sus SMS). Ej: `Prefix1,Mamá`.
  static String deviceName(String name) => 'Prefix1,$name';

  /// `TZ(offset)` — ej: `TZ-03` para Argentina y Uruguay. El reloj del
  /// dispositivo se sincroniza solo desde la red/GPS; esta es la única
  /// forma de corregir la hora que muestra.
  static String timeZone(int offset) {
    final abs = offset.abs().toString().padLeft(2, '0');
    return offset < 0 ? 'TZ-$abs' : 'TZ$abs';
  }

  /// `Low1,(porcentaje)` — alerta automática de batería baja.
  /// Ej: `Low1,20` (valor de fábrica: 20%).
  static String lowBatteryAlert(int percent) => 'Low1,$percent';
}
