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
