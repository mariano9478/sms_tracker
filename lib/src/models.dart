/// Modelos de datos de la app.
library;

/// Un mensaje intercambiado con el rastreador (enviado o recibido).
class SmsRecord {
  const SmsRecord({
    required this.body,
    required this.date,
    required this.incoming,
  });

  final String body;
  final DateTime date;

  /// `true` si lo envió el rastreador, `false` si lo enviamos nosotros.
  final bool incoming;

  Map<String, dynamic> toJson() => {
        'body': body,
        'date': date.millisecondsSinceEpoch,
        'incoming': incoming,
      };

  factory SmsRecord.fromJson(Map<String, dynamic> json) => SmsRecord(
        body: json['body'] as String? ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(json['date'] as int? ?? 0),
        incoming: json['incoming'] as bool? ?? true,
      );

  /// Clave para deduplicar registros al mezclar fuentes.
  String get dedupeKey => '$incoming|${date.millisecondsSinceEpoch}|$body';
}

/// Un contacto de emergencia (SOS) del rastreador. Hay hasta 10 posiciones.
class SosContact {
  const SosContact({
    required this.slot,
    required this.number,
    this.notifyBySms = true,
    this.notifyByCall = true,
  });

  /// Posición 1..10 en el rastreador.
  final int slot;
  final String number;
  final bool notifyBySms;
  final bool notifyByCall;

  Map<String, dynamic> toJson() => {
        'slot': slot,
        'number': number,
        'sms': notifyBySms,
        'call': notifyByCall,
      };

  factory SosContact.fromJson(Map<String, dynamic> json) => SosContact(
        slot: json['slot'] as int? ?? 1,
        number: json['number'] as String? ?? '',
        notifyBySms: json['sms'] as bool? ?? true,
        notifyByCall: json['call'] as bool? ?? true,
      );
}

/// Última ubicación reportada por el rastreador.
class TrackerLocation {
  const TrackerLocation({
    this.latitude,
    this.longitude,
    this.mapUrl,
    this.deviceTime,
    required this.reportedAt,
  });

  final double? latitude;
  final double? longitude;
  final String? mapUrl;

  /// Hora del fix reportada por el dispositivo ("Loc Time"), si vino y se
  /// pudo interpretar. Puede ser incorrecta si el reloj del rastreador no
  /// está sincronizado.
  final DateTime? deviceTime;

  /// Momento en que se recibió el SMS.
  final DateTime reportedAt;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// `true` si la hora reportada por el dispositivo parece confiable
  /// (menos de 48 h de diferencia con la recepción del SMS). Si el
  /// rastreador todavía no sincronizó su reloj con la red/GPS puede
  /// reportar fechas absurdas como 01/01/2034.
  bool get deviceTimeReliable {
    final dt = deviceTime;
    if (dt == null) return false;
    return dt.difference(reportedAt).abs() <= const Duration(hours: 48);
  }

  /// URL para abrir en el navegador / app de mapas. Los rastreadores suelen
  /// mandar el link sin esquema (ej: "smart-locator.com/..."), así que se
  /// normaliza a https.
  String get openUrl {
    final url = mapUrl;
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('http://') || url.startsWith('https://')) return url;
      return 'https://$url';
    }
    return 'https://maps.google.com/?q=$latitude,$longitude';
  }
}
