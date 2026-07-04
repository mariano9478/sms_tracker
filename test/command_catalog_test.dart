import 'package:flutter_test/flutter_test.dart';
import 'package:sms_tracker/src/command_catalog.dart';
import 'package:sms_tracker/src/location_resolver.dart';
import 'package:sms_tracker/src/response_parser.dart';

void main() {
  group('TrackerCommands genera los comandos exactos de la guía', () {
    test('contactos SOS', () {
      expect(
        TrackerCommands.addContact(
          slot: 1,
          sms: true,
          call: true,
          number: '1138889888',
        ),
        'A1,1,1,1138889888',
      );
      expect(TrackerCommands.viewContacts, 'A?');
      expect(TrackerCommands.removeContact(3), 'removeA3');
    });

    test('botón lateral', () {
      expect(TrackerCommands.sideButton(1), 'X1');
      // Con CERO, no letra O (guía v1.5).
      expect(TrackerCommands.sideButtonOff, 'X0');
    });

    test('sensores y alarmas', () {
      expect(
        TrackerCommands.fallSensor(sensitivity: 5, call: true),
        'FL1,5,1',
      );
      expect(TrackerCommands.fallSensorOff, 'FL0');
      expect(TrackerCommands.geofence(meters: 100), 'GEO1,1,0,100M');
      expect(
        TrackerCommands.geofence(slot: 2, meters: 500),
        'GEO2,1,0,500M',
      );
      expect(
        TrackerCommands.noMovement(amount: 80, call: true),
        'NMO1,80M,1',
      );
      expect(
        TrackerCommands.noMovement(amount: 10, unit: 'H', call: false),
        'NMO1,10H,0',
      );
      expect(TrackerCommands.noMovementOff, 'NMO0');
    });

    test('secuencia de llamadas y llamadas entrantes', () {
      expect(TrackerCommands.callSequence(interrupt: false), 'SCS0');
      expect(TrackerCommands.callSequence(interrupt: true), 'SCS1');
      expect(TrackerCommands.callIn(all: true), 'callin1');
      expect(TrackerCommands.callIn(all: false), 'callin0');
    });

    test('consultas', () {
      expect(TrackerCommands.locate, 'loc');
      expect(TrackerCommands.battery, 'Battery');
      expect(TrackerCommands.status, 'Status');
      expect(TrackerCommands.findMe, 'Findme');
    });

    test('avanzados y audio', () {
      expect(TrackerCommands.remoteListenOn, 'LT1');
      expect(TrackerCommands.remoteListenOff, 'LT0');
      expect(TrackerCommands.ringVolume(50), 'rt50');
      expect(TrackerCommands.micVolume(10), 'micvolume10');
      expect(TrackerCommands.speakerVolume(90), 'speakervolume90');
      expect(TrackerCommands.sosSpeaker(on: true), 'sosspeaker1');
      expect(TrackerCommands.sosSpeaker(on: false), 'sosspeaker0');
      expect(TrackerCommands.beepVoices(on: true), 'beep1');
      expect(TrackerCommands.beepVoices(on: false), 'beep0');
      expect(TrackerCommands.deviceName('Mamá'), 'Prefix1,Mamá');
      expect(TrackerCommands.timeZone(-3), 'TZ-03');
      expect(TrackerCommands.timeZone(5), 'TZ05');
      expect(TrackerCommands.lowBatteryAlert(20), 'Low1,20');
    });
  });

  group('ResponseParser', () {
    test('batería', () {
      expect(ResponseParser.parseBattery('Battery: 85%'), 85);
      expect(ResponseParser.parseBattery('Power 100 %'), 100);
      expect(ResponseParser.parseBattery('sin porcentaje'), isNull);
      expect(ResponseParser.parseBattery('999%'), isNull);
    });

    test('ubicación con link y coordenadas', () {
      final now = DateTime(2026, 1, 1);
      final loc = ResponseParser.parseLocation(
        'Posicion: http://maps.google.com/maps?q=-34.60371,-58.38157',
        now,
      );
      expect(loc, isNotNull);
      expect(loc!.latitude, closeTo(-34.60371, 0.0001));
      expect(loc.longitude, closeTo(-58.38157, 0.0001));
      expect(loc.mapUrl, contains('maps.google.com'));
    });

    test('respuesta real de loc: link sin esquema, Loc Time y batería', () {
      const sample = 'GSM and WIFI-Loc:\n'
          'Loc Time:01/01/2034 00:00:00\n'
          'Battery:83%\n'
          'smart-locator.com/web/geolocation/wg/JCLAmB4Zs1-Cv5oeGbNghrzgN78'
          'BtKW3klhRbmQct5BYUW5kGCch0gIiGvwTVbYU9RPQGA31E-qpDfUTzxgK9RO0pgX'
          '8E2u1CPwTa7U=';
      final now = DateTime(2026, 7, 4, 12, 30);

      final loc = ResponseParser.parseLocation(sample, now);
      expect(loc, isNotNull);
      expect(loc!.hasCoordinates, isFalse);
      expect(loc.mapUrl, startsWith('smart-locator.com/web/geolocation/'));
      // El link sin esquema se normaliza a https y conserva el token
      // completo (incluido el '=' final).
      expect(loc.openUrl,
          startsWith('https://smart-locator.com/web/geolocation/'));
      expect(loc.openUrl, endsWith('='));
      expect(loc.reportedAt, now);
      expect(loc.deviceTime, DateTime(2034, 1, 1, 0, 0, 0));
      // Reloj sin sincronizar (2034 vs 2026): se marca como no confiable.
      expect(loc.deviceTimeReliable, isFalse);

      // La misma respuesta trae la batería.
      expect(ResponseParser.parseBattery(sample), 83);
    });

    test('sin ubicación', () {
      expect(
        ResponseParser.parseLocation('Battery: 85%', DateTime(2026)),
        isNull,
      );
    });

    test('mensaje SOS real: detección, Alarm Time, ubicación y batería', () {
      const sos = 'Help Me\n'
          'GSM and WIFI-Loc:\n'
          'Loc Time:05/07/2026 07:41:27\n'
          'Alarm Time:05/07/2026 07:41:19\n'
          'Battery:77%\n'
          'smart-locator.com/web/geolocation/wg/JCLRyrQiFZ3Xz8i0IhWd18182'
          '5jYFA_IumaF-3bYyLhmhft03ych0gIiHPUTtKYU9RO2phT1E1IXFPwT7WcR9RP'
          'QGBD8E7dhD_UTTRc=';

      expect(ResponseParser.isSosAlert(sos), isTrue);
      expect(
        ResponseParser.parseAlarmTime(sos),
        DateTime(2026, 7, 5, 7, 41, 19),
      );
      expect(ResponseParser.parseBattery(sos), 77);

      final loc = ResponseParser.parseLocation(sos, DateTime(2026, 7, 5, 8));
      expect(loc, isNotNull);
      expect(loc!.mapUrl, startsWith('smart-locator.com/'));
      expect(loc.deviceTime, DateTime(2026, 7, 5, 7, 41, 27));
      // Reloj sincronizado (misma fecha que la recepción): confiable.
      expect(loc.deviceTimeReliable, isTrue);

      // Los mensajes normales NO deben disparar la alerta.
      expect(ResponseParser.isSosAlert('Battery: 85%'), isFalse);
      expect(
        ResponseParser.isSosAlert('GSM and WIFI-Loc:\nLoc Time:01/01/2034 '
            '00:00:00\nBattery:83%\nsmart-locator.com/web/x'),
        isFalse,
      );
    });

    test('coordenadas desde URLs de Google Maps (redirect del link)', () {
      expect(
        LocationResolver.extractCoordinates(
            'https://maps.google.com/maps?q=-34.60371,-58.38157'),
        (lat: -34.60371, lng: -58.38157),
      );
      expect(
        LocationResolver.extractCoordinates(
            'https://www.google.com/maps/@-34.60371,-58.38157,17z'),
        (lat: -34.60371, lng: -58.38157),
      );
      // Coma codificada en la URL.
      expect(
        LocationResolver.extractCoordinates(
            'https://maps.google.com/?q=-34.60371%2C-58.38157'),
        (lat: -34.60371, lng: -58.38157),
      );
      // Sin coordenadas plausibles.
      expect(
        LocationResolver.extractCoordinates(
            'https://smart-locator.com/web/geolocation/wg/ABC123='),
        isNull,
      );
      // Fuera de rango.
      expect(
        LocationResolver.extractCoordinates('q=134.60371,-258.38157'),
        isNull,
      );
    });

    test('contactos desde respuesta A?', () {
      final contacts = ResponseParser.parseContacts(
        'A1,1,1,1138889888\nA2,1,0,1144445555',
      );
      expect(contacts, hasLength(2));
      expect(contacts.first.slot, 1);
      expect(contacts.first.number, '1138889888');
      expect(contacts.last.notifyByCall, isFalse);
    });
  });
}
