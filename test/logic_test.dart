import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:women_safety_app/models/app_settings.dart';
import 'package:women_safety_app/models/incident.dart';
import 'package:women_safety_app/models/location_fix.dart';
import 'package:women_safety_app/screens/contacts_screen.dart';
import 'package:women_safety_app/services/auth_service.dart';
import 'package:women_safety_app/services/shake_service.dart';
import 'package:women_safety_app/services/sos_service.dart';
import 'package:women_safety_app/services/storage_service.dart';

void main() {
  group('SosMessages', () {
    final now = DateTime(2026, 10, 31, 22, 15);
    final fix = LocationFix(
      latitude: 12.9716,
      longitude: 77.5946,
      accuracy: 14.4,
      time: now,
    );

    test('fits in the GSM alphabet so it is not split at 70 characters', () {
      final messages = [
        SosMessages.alert(name: 'Priya', fix: fix, now: now, bloodGroup: 'O+'),
        SosMessages.update(fix: fix, now: now),
        SosMessages.allClear('Priya'),
        SosMessages.test('Priya'),
        SosMessages.walkStarted('Priya', 'Home', now),
      ];
      for (final message in messages) {
        expect(message.codeUnits.every((c) => c < 128), isTrue, reason: message);
      }
    });

    test('has a tappable, correctly formatted map link', () {
      final message = SosMessages.alert(name: 'Priya', fix: fix, now: now);
      expect(message,
          contains('https://maps.google.com/?q=12.971600,77.594600 '));
      expect(message, contains('within 14 m, 22:15'));
    });

    test('never presents an old position as current', () {
      final old = LocationFix(
        latitude: 1,
        longitude: 2,
        accuracy: 3,
        time: now.subtract(const Duration(minutes: 30)),
      );
      final message = SosMessages.alert(name: 'Priya', fix: old, now: now);
      expect(message, contains('Last known location'));
    });

    test('still reads properly with no profile or location', () {
      final message = SosMessages.alert(name: ' ', fix: null, now: now);
      expect(message, startsWith('SOS! Your contact needs help now.'));
      expect(message, contains('Location unavailable'));
      expect(message, isNot(contains('Blood group')));
    });

    test('uses the custom message when there is one', () {
      final message = SosMessages.alert(
        name: 'Priya',
        fix: fix,
        now: now,
        customMessage: 'I am being followed.',
      );
      expect(message, startsWith('SOS from Priya: I am being followed.'));
      expect(message, contains('maps.google.com'));
    });
  });

  group('ShakeDetector', () {
    final start = DateTime(2026);

    bool feed(ShakeDetector detector, List<(int, double)> peaks) {
      var fired = false;
      for (final (ms, force) in peaks) {
        final time = start.add(Duration(milliseconds: ms));
        fired = detector.addSample(force, 0, 0, time) || fired;
      }
      return fired;
    }

    test('four hard shakes in a row trigger', () {
      expect(
        feed(ShakeDetector(), [(0, 35), (250, 35), (500, 35), (750, 35)]),
        isTrue,
      );
    });

    test('walking and running do not', () {
      final steps = [for (var i = 0; i < 200; i++) (i * 300, 18.0)];
      expect(feed(ShakeDetector(), steps), isFalse);
    });

    test('isolated bumps spread over time do not add up', () {
      final bumps = [for (var i = 0; i < 20; i++) (i * 2000, 40.0)];
      expect(feed(ShakeDetector(), bumps), isFalse);
    });

    test('one long jolt does not count as several peaks', () {
      final jolt = [for (var i = 0; i < 30; i++) (i * 10, 40.0)];
      expect(feed(ShakeDetector(), jolt), isFalse);
    });
  });

  group('cleanPhoneNumber', () {
    test('removes formatting', () {
      expect(cleanPhoneNumber('+91 98765-43210'), '+919876543210');
      expect(cleanPhoneNumber(' (080) 2222 3333 '), '08022223333');
    });

    test('rejects what cannot be dialled', () {
      expect(cleanPhoneNumber('123'), isNull);
      expect(cleanPhoneNumber('abcdefgh'), isNull);
      expect(cleanPhoneNumber('1234567890123456'), isNull);
    });
  });

  group('AuthService', () {
    late AuthService auth;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      auth = AuthService();
    });

    test('a new account can log back in', () async {
      expect(await auth.hasAccount(), isFalse);
      await auth.signUp(name: 'Priya', phone: '9800000001', password: 'secret1');
      expect(await auth.hasAccount(), isTrue);
      expect(await StorageService().isLoggedIn(), isTrue);
      expect((await StorageService().getProfile())['name'], 'Priya');

      await StorageService().setLoggedIn(false);
      expect(
        await auth.logIn(phone: '9800000001', password: 'secret1'),
        isTrue,
      );
    });

    test('a wrong password or phone is refused', () async {
      await auth.signUp(name: 'Priya', phone: '9800000001', password: 'secret1');
      await StorageService().setLoggedIn(false);
      expect(await auth.logIn(phone: '9800000001', password: 'nope'), isFalse);
      expect(await auth.logIn(phone: '111111', password: 'secret1'), isFalse);
      expect(await StorageService().isLoggedIn(), isFalse);
    });

    test('the password is not stored', () async {
      await auth.signUp(name: 'Priya', phone: '9800000001', password: 'secret1');
      final stored = jsonEncode(await StorageService().getCredentials());
      expect(stored, isNot(contains('secret1')));
    });

    test('the same password hashes differently per account', () async {
      await auth.signUp(name: 'A', phone: '9800000001', password: 'secret1');
      final first = (await StorageService().getCredentials())!['hash'];
      await auth.signUp(name: 'A', phone: '9800000001', password: 'secret1');
      final second = (await StorageService().getCredentials())!['hash'];
      expect(first, isNot(second));
    });

    test('resetting the account keeps the contacts', () async {
      SharedPreferences.setMockInitialValues({
        'emergency_contacts': [
          jsonEncode({'id': '1', 'name': 'A', 'phone': '1', 'relation': 'x'}),
        ],
      });
      await auth.signUp(name: 'A', phone: '9800000001', password: 'secret1');
      await auth.resetAccount();
      expect(await auth.hasAccount(), isFalse);
      expect(await StorageService().getContacts(), hasLength(1));
    });
  });

  group('storage', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('settings from an older install fall back to defaults', () {
      final settings = AppSettings.fromJson({'shakeEnabled': true});
      expect(settings.shakeEnabled, isTrue);
      expect(settings.countdownSeconds, 5);
      expect(settings.emergencyNumber, '112');
    });

    test('incidents round-trip, newest first, and the log is capped', () async {
      final storage = StorageService();
      for (var i = 0; i < 55; i++) {
        await storage.addIncident(Incident(
          id: '$i',
          startedAt: DateTime(2026, 1, 1, 0, i),
          trigger: IncidentTrigger.shake,
          latitude: 1.5,
          alerts: [
            ContactAlert(
              contactId: '1',
              name: 'A',
              phone: '1',
              status: AlertStatus.composer,
            ),
          ],
        ));
      }
      final log = await storage.getIncidents();
      expect(log, hasLength(50));
      expect(log.first.id, '54');
      expect(log.first.trigger, IncidentTrigger.shake);
      expect(log.first.alerts.single.status, AlertStatus.composer);
      expect(log.first.latitude, 1.5);
    });
  });
}
