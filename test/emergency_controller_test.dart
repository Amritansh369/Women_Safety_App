import 'dart:convert';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:women_safety_app/models/incident.dart';
import 'package:women_safety_app/services/emergency_controller.dart';
import 'package:women_safety_app/services/sms_service.dart';
import 'package:women_safety_app/services/storage_service.dart';
import 'fakes.dart';

const asha = '+919800000001';
const meera = '+919800000002';

void seedPrefs({List<String> phones = const [asha, meera], String? settings}) {
  SharedPreferences.setMockInitialValues({
    'emergency_contacts': [
      for (final phone in phones)
        jsonEncode({
          'id': phone,
          'name': 'Contact $phone',
          'phone': phone,
          'relation': 'Friend',
        }),
    ],
    'profile_name': 'Priya',
    'profile_blood_group': 'O+',
    'app_settings': ?settings,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSms sms;
  late FakeLocation location;
  late FakeSiren siren;
  late EmergencyController controller;

  EmergencyController build() => EmergencyController(
        sms: sms,
        location: location,
        storage: StorageService(),
        siren: siren,
      );

  /// Runs [body] in fake time, on a controller with fresh fakes.
  void run(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      sms = FakeSms();
      location = FakeLocation();
      siren = FakeSiren();
      controller = build();
      body(async);
    });
  }

  void pressSos(FakeAsync async) {
    controller.startCountdown(IncidentTrigger.button);
    async.flushMicrotasks();
  }

  setUp(seedPrefs);

  group('countdown', () {
    test('cancelling sends nothing, ever', () => run((async) {
          pressSos(async);
          async.elapse(const Duration(seconds: 3));
          controller.cancelCountdown();
          async.elapse(const Duration(minutes: 10));
          expect(controller.phase, EmergencyPhase.idle);
          expect(sms.attempts, isEmpty);
        }));

    test('alerts every contact when it reaches zero', () => run((async) {
          location.current = freshFix();
          pressSos(async);
          expect(controller.phase, EmergencyPhase.countdown);
          async.elapse(const Duration(seconds: 4));
          expect(sms.sent, isEmpty);
          async.elapse(const Duration(seconds: 2));

          expect(controller.phase, EmergencyPhase.active);
          expect(sms.sent.map((s) => s.phone), unorderedEquals([asha, meera]));
          expect(sms.sent.first.message, contains('Priya'));
          expect(sms.sent.first.message, contains('maps.google.com'));
          expect(sms.sent.first.message, contains('O+'));
          expect(controller.incident!.countWhere(AlertStatus.sent), 2);
        }));

    test('a second trigger during an SOS does not double-alert', () => run((async) {
          location.current = freshFix();
          pressSos(async);
          pressSos(async);
          async.elapse(const Duration(seconds: 6));
          pressSos(async);
          controller.triggerNow(IncidentTrigger.shake);
          async.elapse(const Duration(seconds: 6));
          expect(sms.attempts[asha], 1);
        }));

    test('respects the configured length', () {
      seedPrefs(settings: jsonEncode({'countdownSeconds': 10}));
      run((async) {
        location.current = freshFix();
        pressSos(async);
        expect(controller.secondsLeft, 10);
        async.elapse(const Duration(seconds: 9));
        expect(sms.sent, isEmpty);
        async.elapse(const Duration(seconds: 2));
        expect(sms.sent, hasLength(2));
      });
    });
  });

  group('alert survives location failure', () {
    test('sends without a location when GPS has nothing', () => run((async) {
          pressSos(async);
          async.elapse(const Duration(seconds: 6));
          expect(sms.sent, hasLength(2));
          expect(sms.sent.first.message, contains('Location unavailable'));
        }));

    test('sends even if the location service throws', () => run((async) {
          location.throws = true;
          pressSos(async);
          async.elapse(const Duration(seconds: 6));
          expect(sms.sent, hasLength(2));
        }));

    test('falls back to the last known position, labelled as old', () => run((async) {
          location.last = fixAt(DateTime(2020));
          pressSos(async);
          async.elapse(const Duration(seconds: 6));
          expect(sms.sent.first.message, contains('Last known location'));
        }));

    test('a slow GPS cannot hold the alert back', () => run((async) {
          location.currentDelay = const Duration(seconds: 2);
          pressSos(async);
          async.elapse(const Duration(seconds: 8));
          expect(sms.sent, hasLength(2));
        }));

    test('sends the real position as soon as it arrives', () => run((async) {
          pressSos(async);
          async.elapse(const Duration(seconds: 6));
          expect(sms.sent, hasLength(2));

          location.stream.add(freshFix());
          async.elapse(const Duration(seconds: 1));

          expect(sms.sent, hasLength(4));
          expect(sms.sent.last.message, contains('maps.google.com'));
          expect(controller.incident!.updatesSent, 1);
        }));

    test('a fix arriving mid-send is not lost for a stationary user',
        () => run((async) {
          sms.delays[asha] = const Duration(seconds: 3);
          pressSos(async);
          async.elapse(const Duration(seconds: 6));
          location.stream.add(freshFix());
          async.elapse(const Duration(seconds: 5));
          expect(controller.incident!.updatesSent, 1);
        }));
  });

  group('sending', () {
    test('retries a failed SMS until it goes through', () => run((async) {
          location.current = freshFix();
          sms.failuresLeft[asha] = 2;
          pressSos(async);
          async.elapse(const Duration(seconds: 20));
          expect(sms.attempts[asha], 3);
          expect(controller.incident!.alerts.first.status, AlertStatus.sent);
        }));

    test('reports failure honestly, then recovers on manual retry', () => run((async) {
          location.current = freshFix();
          sms.failuresLeft[asha] = 3;
          pressSos(async);
          async.elapse(const Duration(seconds: 20));
          final alerts = controller.incident!.alerts;
          expect(alerts.firstWhere((a) => a.phone == asha).status,
              AlertStatus.failed);
          expect(alerts.firstWhere((a) => a.phone == meera).status,
              AlertStatus.sent);

          controller.retryFailed();
          async.elapse(const Duration(seconds: 5));
          expect(alerts.firstWhere((a) => a.phone == asha).status,
              AlertStatus.sent);
        }));

    test('keeps retrying by itself until signal returns', () => run((async) {
          location.current = freshFix();
          sms.failuresLeft[asha] = 12;
          sms.failuresLeft[meera] = 12;
          pressSos(async);
          async.elapse(const Duration(seconds: 30));
          expect(controller.incident!.countWhere(AlertStatus.failed), 2);

          async.elapse(const Duration(minutes: 3));

          expect(controller.incident!.countWhere(AlertStatus.sent), 2);
          expect(controller.incident!.countWhere(AlertStatus.failed), 0);
          expect(sms.sent.first.message, startsWith('SOS!'));
        }));

    test('stops retrying once the user is safe', () => run((async) {
          location.current = freshFix();
          sms.failuresLeft[asha] = 100000;
          pressSos(async);
          async.elapse(const Duration(seconds: 30));
          controller.markSafe();
          async.elapse(const Duration(seconds: 20));
          final attempts = sms.attempts[asha];
          async.elapse(const Duration(minutes: 10));
          expect(sms.attempts[asha], attempts);
        }));

    test('one stuck number does not delay the others', () => run((async) {
          location.current = freshFix();
          sms.delays[asha] = const Duration(seconds: 50);
          pressSos(async);
          async.elapse(const Duration(seconds: 6));
          expect(sms.sent.map((s) => s.phone), [meera]);
        }));

    test('without SMS permission the composer opens and is never called sent',
        () => run((async) {
          location.current = freshFix();
          sms.alwaysReturn = SmsResult.noPermission;
          pressSos(async);
          async.elapse(const Duration(seconds: 6));

          expect(sms.composerCalls.single, unorderedEquals([asha, meera]));
          final incident = controller.incident!;
          expect(incident.countWhere(AlertStatus.composer), 2);
          expect(incident.countWhere(AlertStatus.sent), 0);
        }));

    test('a composer that will not open counts as failed', () => run((async) {
          sms.alwaysReturn = SmsResult.unsupported;
          sms.composerOpens = false;
          pressSos(async);
          async.elapse(const Duration(seconds: 6));
          expect(controller.incident!.countWhere(AlertStatus.failed), 2);
        }));

    test('no contacts still opens the emergency screen', () {
      seedPrefs(phones: const []);
      run((async) {
        location.current = freshFix();
        pressSos(async);
        async.elapse(const Duration(seconds: 6));
        expect(controller.phase, EmergencyPhase.active);
        expect(controller.dispatching, isFalse);
        expect(controller.incident!.alerts, isEmpty);
      });
    });

    test('siren only starts when the user chose that', () {
      seedPrefs(settings: jsonEncode({'sirenOnSos': true}));
      run((async) {
        pressSos(async);
        async.elapse(const Duration(seconds: 6));
        expect(siren.isPlaying, isTrue);
      });
    });

    test('siren stays silent by default', () => run((async) {
          pressSos(async);
          async.elapse(const Duration(seconds: 6));
          expect(siren.isPlaying, isFalse);
        }));
  });

  group('while active', () {
    test('keeps sending updates, only to contacts who were reached', () => run((async) {
          location.current = freshFix();
          sms.failuresLeft[asha] = 100000;
          pressSos(async);
          async.elapse(const Duration(seconds: 30));
          final before = sms.sent.length;

          location.current = freshFix();
          async.elapse(const Duration(minutes: 5));

          expect(sms.sent.length, before + 1);
          expect(sms.sent.last.phone, meera);
          expect(sms.sent.last.message, contains('SOS still active'));
        }));

    test('re-reads GPS for a stationary user instead of going stale',
        () => run((async) {
          location.current = freshFix();
          pressSos(async);
          async.elapse(const Duration(seconds: 6));

          async.elapse(const Duration(minutes: 3));
          location.current = freshFix();
          async.elapse(const Duration(minutes: 2));

          expect(sms.sent.last.message, isNot(contains('Last known')));
          expect(sms.sent.last.message, contains('Location: '));
        }));

    test('keeps location running in the background', () => run((async) {
          pressSos(async);
          async.elapse(const Duration(seconds: 6));
          expect(location.holds, contains('emergency'));
        }));
  });

  group("I'm safe", () {
    test('tells contacts, stops everything, and files the incident', () => run((async) {
          location.current = freshFix();
          pressSos(async);
          async.elapse(const Duration(seconds: 6));
          controller.toggleSiren();
          async.flushMicrotasks();

          controller.markSafe();
          async.elapse(const Duration(seconds: 1));

          expect(controller.phase, EmergencyPhase.idle);
          expect(siren.isPlaying, isFalse);
          expect(location.holds, isEmpty);
          expect(sms.sent.last.message, contains('marked themselves safe'));

          final count = sms.sent.length;
          async.elapse(const Duration(hours: 1));
          expect(sms.sent.length, count, reason: 'updates must stop');

          late List<Incident> log;
          StorageService().getIncidents().then((value) => log = value);
          async.flushMicrotasks();
          expect(log.single.endedAt, isNotNull);
          expect(log.single.countWhere(AlertStatus.sent), 2);
        }));
  });

  group('app killed mid-SOS', () {
    test('resumes without re-alerting, and keeps updates going', () {
      late List<SentSms> firstRun;
      run((async) {
        location.current = freshFix();
        pressSos(async);
        async.elapse(const Duration(seconds: 6));
        firstRun = List.of(sms.sent);

        // A new process: new controller, same stored data.
        final restarted = build();
        location.current = freshFix();
        restarted.resumeIfActive();
        async.elapse(const Duration(seconds: 1));

        expect(firstRun, hasLength(2));
        expect(restarted.phase, EmergencyPhase.active);
        expect(sms.sent.skip(2).every((s) => s.message.contains('still active')),
            isTrue);
        expect(restarted.incident!.countWhere(AlertStatus.sent), 2);
      });
    });

    test('does nothing when no SOS was running', () => run((async) {
          controller.resumeIfActive();
          async.flushMicrotasks();
          expect(controller.phase, EmergencyPhase.idle);
        }));
  });
}
