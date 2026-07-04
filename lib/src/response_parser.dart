import 'models.dart';

/// Extrae información útil (batería, ubicación, contactos) de las
/// respuestas SMS del rastreador, con heurísticas tolerantes porque el
/// formato exacto varía entre firmwares.
///
/// Formato real de la respuesta de ubicación (comando `loc`):
/// ```
/// GSM and WIFI-Loc:
/// Loc Time:01/01/2034 00:00:00
/// Battery:83%
/// smart-locator.com/web/geolocation/wg/JCLAmB4Zs1-...
/// ```
/// Notar que el link viene SIN `http://` y que la misma respuesta incluye
/// la batería.
///
/// Cuando se activa el botón SOS, el mensaje llega con este formato:
/// ```
/// Help Me
/// GSM and WIFI-Loc:
/// Loc Time:05/07/2026 07:41:27
/// Alarm Time:05/07/2026 07:41:19
/// Battery:77%
/// smart-locator.com/web/geolocation/wg/JCLRyrQiFZ3X...
/// ```
class ResponseParser {
  ResponseParser._();

  static final RegExp _percent = RegExp(r'(\d{1,3})\s*%');

  /// URLs con o sin esquema: "https://x.com/a", "smart-locator.com/web/...".
  static final RegExp _url = RegExp(
    r'(?:https?://)?(?:[\w-]+\.)+[a-zA-Z]{2,}/\S+',
    caseSensitive: false,
  );

  static final RegExp _coords =
      RegExp(r'(-?\d{1,3}\.\d{3,})\s*,\s*(-?\d{1,3}\.\d{3,})');

  /// "Loc Time:01/01/2034 00:00:00" (dd/MM/yyyy HH:mm:ss).
  static final RegExp _locTime = RegExp(
    r'Loc\s*Time\s*:\s*(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})',
    caseSensitive: false,
  );

  /// "Alarm Time:05/07/2026 07:41:19" — presente en los mensajes de SOS.
  static final RegExp _alarmTime = RegExp(
    r'Alarm\s*Time\s*:\s*(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})',
    caseSensitive: false,
  );

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
    // Limpia puntuación final que a veces viene pegada al link (sin tocar
    // los '=' del token de smart-locator).
    if (url != null) {
      url = url.replaceAll(RegExp(r'''[.,;)\]'"”“]+$'''), '');
    }

    if (url == null && lat == null) return null;
    return TrackerLocation(
      latitude: lat,
      longitude: lng,
      mapUrl: url,
      deviceTime: _parseLocTime(body),
      reportedAt: reportedAt,
    );
  }

  static DateTime? _parseLocTime(String body) =>
      _dateTimeFromMatch(_locTime.firstMatch(body));

  /// `true` si el mensaje es una alerta de emergencia (botón SOS, caída…).
  static bool isSosAlert(String body) {
    final lower = body.toLowerCase();
    return lower.contains('help me') || lower.contains('alarm time');
  }

  /// Hora de activación de la alarma en un mensaje de SOS, si se puede
  /// interpretar (dd/MM/yyyy HH:mm:ss).
  static DateTime? parseAlarmTime(String body) =>
      _dateTimeFromMatch(_alarmTime.firstMatch(body));

  static DateTime? _dateTimeFromMatch(RegExpMatch? m) {
    if (m == null) return null;
    try {
      final day = int.parse(m.group(1)!);
      final month = int.parse(m.group(2)!);
      final year = int.parse(m.group(3)!);
      final hour = int.parse(m.group(4)!);
      final minute = int.parse(m.group(5)!);
      final second = int.parse(m.group(6)!);
      if (month < 1 || month > 12 || day < 1 || day > 31 || hour > 23) {
        return null;
      }
      return DateTime(year, month, day, hour, minute, second);
    } catch (_) {
      return null;
    }
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
