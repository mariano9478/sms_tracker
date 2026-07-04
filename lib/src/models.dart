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
    required this.reportedAt,
  });

  final double? latitude;
  final double? longitude;
  final String? mapUrl;
  final DateTime reportedAt;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// URL para abrir en la app de mapas.
  String get openUrl {
    if (mapUrl != null && mapUrl!.isNotEmpty) return mapUrl!;
    return 'https://maps.google.com/?q=$latitude,$longitude';
  }
}
