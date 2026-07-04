import 'package:flutter_test/flutter_test.dart';
import 'package:sms_tracker/src/command_catalog.dart';
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
      expect(TrackerCommands.sideButtonOff, 'XO');
    });

    test('sensores y alarmas', () {
      expect(
        TrackerCommands.fallSensor(sensitivity: 5, call: true),
        'FL1,5,1',
      );
      expect(TrackerCommands.fallSensorOff, 'FLO');
      expect(TrackerCommands.geofence(meters: 100), 'GE01,1,0,100M');
      expect(
        TrackerCommands.noMovement(minutes: 80, call: true),
        'NMO1,80M,1',
      );
      expect(TrackerCommands.noMovementOff, 'NMOO');
    });

    test('consultas', () {
      expect(TrackerCommands.locate, 'loc');
      expect(TrackerCommands.battery, 'Battery');
      expect(TrackerCommands.status, 'Status');
      expect(TrackerCommands.findMe, 'Findme');
    });

    test('avanzados y audio', () {
      expect(TrackerCommands.remoteListenOn, 'LT1');
      expect(TrackerCommands.remoteListenOff, 'LTO');
      expect(TrackerCommands.ringVolume(50), r'$rt50$');
      expect(TrackerCommands.micVolume(10), 'micvolume10');
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

      // La misma respuesta trae la batería.
      expect(ResponseParser.parseBattery(sample), 83);
    });

    test('sin ubicación', () {
      expect(
        ResponseParser.parseLocation('Battery: 85%', DateTime(2026)),
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
