import 'dart:convert';
import 'dart:io';

/// Convierte el link de ubicación del rastreador en coordenadas.
///
/// Los links de smart-locator redirigen a Google Maps: se siguen las
/// redirecciones HTTP y se extraen lat/lng de la URL final
/// (ej: `maps.google.com/maps?q=-34.603,-58.381`). Como último recurso se
/// buscan coordenadas en el cuerpo de la página final.
class LocationResolver {
  LocationResolver._();

  static const int _maxHops = 6;
  static const int _maxBodyBytes = 200 * 1024;

  static final RegExp _coords =
      RegExp(r'(-?\d{1,3}\.\d{2,})\s*,\s*(-?\d{1,3}\.\d{2,})');

  /// Sigue las redirecciones de [url] y devuelve las coordenadas, o `null`
  /// si no se pudieron obtener (sin internet, link vencido, etc.).
  static Future<({double lat, double lng})?> resolve(String url) async {
    var current =
        Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (current == null) return null;

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      for (var hop = 0; hop < _maxHops; hop++) {
        // Muchas veces las coordenadas ya están en la propia URL.
        final fromUrl = extractCoordinates(current.toString());
        if (fromUrl != null) return fromUrl;

        final request = await client.getUrl(current!);
        request.followRedirects = false;
        final response = await request.close();

        if (response.isRedirect) {
          final next = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>();
          if (next == null) return null;
          current = current.resolve(next);
          continue;
        }

        // Página final sin coordenadas en la URL: se busca en el HTML.
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > _maxBodyBytes) break;
        }
        final body =
            const Utf8Decoder(allowMalformed: true).convert(bytes);
        return extractCoordinates(body);
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Extrae el primer par lat,lng plausible de [text] (URL o HTML).
  /// Acepta la coma codificada como `%2C`.
  static ({double lat, double lng})? extractCoordinates(String text) {
    final normalized =
        text.replaceAll('%2C', ',').replaceAll('%2c', ',');
    for (final match in _coords.allMatches(normalized)) {
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat == null || lng == null) continue;
      if (lat.abs() > 90 || lng.abs() > 180) continue;
      if (lat == 0 && lng == 0) continue;
      return (lat: lat, lng: lng);
    }
    return null;
  }
}
