import 'models.dart';

/// Extrae información útil (batería, ubicación, contactos) de las
/// respuestas SMS del rastreador, con heurísticas tolerantes porque el
/// formato exacto varía entre firmwares.
class ResponseParser {
  ResponseParser._();

  static final RegExp _percent = RegExp(r'(\d{1,3})\s*%');
  static final RegExp _url = RegExp(r'https?://\S+', caseSensitive: false);
  static final RegExp _coords =
      RegExp(r'(-?\d{1,3}\.\d{3,})\s*,\s*(-?\d{1,3}\.\d{3,})');
  static final RegExp _contactLine = RegExp(
    r'A(\d{1,2})\s*[,:]\s*([01])\s*,\s*([01])\s*,\s*(\+?\d{5,})',
    caseSensitive: false,
  );

  /// Porcentaje de batería si el mensaje lo contiene.
  static int? parseBattery(String body) {
    final match = _percent.firstMatch(body);
    if (match == null) return null;
    final value = int.tryParse(match.group(1)!);
    if (value == null || value < 0 || value > 100) return null;
    return value;
  }

  /// Ubicación (link de mapa y/o coordenadas) si el mensaje la contiene.
  static TrackerLocation? parseLocation(String body, DateTime reportedAt) {
    final urlMatch = _url.firstMatch(body);
    final coordMatch = _coords.firstMatch(body);
    if (urlMatch == null && coordMatch == null) return null;

    double? lat;
    double? lng;
    if (coordMatch != null) {
      lat = double.tryParse(coordMatch.group(1)!);
      lng = double.tryParse(coordMatch.group(2)!);
      if (lat != null && (lat < -90 || lat > 90)) lat = null;
      if (lng != null && (lng < -180 || lng > 180)) lng = null;
      if (lat == null || lng == null) {
        lat = null;
        lng = null;
      }
    }

    String? url = urlMatch?.group(0);
    // Limpia puntuación final que a veces viene pegada al link.
    if (url != null) {
      url = url.replaceAll(RegExp(r'[.,;)\]]+$'), '');
    }

    if (url == null && lat == null) return null;
    return TrackerLocation(
      latitude: lat,
      longitude: lng,
      mapUrl: url,
      reportedAt: reportedAt,
    );
  }

  /// Contactos SOS reportados en la respuesta al comando `A?`.
  static List<SosContact> parseContacts(String body) {
    return _contactLine.allMatches(body).map((m) {
      return SosContact(
        slot: int.parse(m.group(1)!),
        notifyBySms: m.group(2) == '1',
        notifyByCall: m.group(3) == '1',
        number: m.group(4)!,
      );
    }).toList();
  }
}
