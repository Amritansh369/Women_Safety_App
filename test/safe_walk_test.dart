import 'dart:convert';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:women_safety_app/services/emergency_controller.dart';
import 'package:women_safety_app/services/safe_walk_controller.dart';
import 'package:women_safety_app/services/storage_service.dart';
import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSms sms;
  late FakeLocation location;
  late FakeSiren alarm;
  late EmergencyController emergency;
  late SafeWalkController walk;

  SafeWalkController build() => SafeWalkController(
        emergency: emergency,
        location: location,
        storage: StorageService(),
        sms: sms,
        alarm: alarm,
      );

  void run(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      sms = FakeSms();
      location = FakeLocation()..current = freshFix();
      alarm = FakeSiren();
      emergency = EmergencyController(
        sms: sms,
        location: location,
        storage: StorageService(),
        siren: FakeSiren(),
      );
      walk = build();
      body(async);
    });
  }

  void startWalk(FakeAsync async, {bool notify = false}) {
    walk.start(
      duration: const Duration(minutes: 10),
      destination: 'Home',
      notifyContacts: notify,
    );
    async.flushMicrotasks();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'emergency_contacts': [
        jsonEncode({
          'id': '1',
          'name': 'Asha',
          'phone': '+919800000001',
          'relation': 'Sister',
        }),
      ],
    });
  });

  test('arriving on time ends the walk with no alert', () => run((async) {
        startWalk(async);
        async.elapse(const Duration(minutes: 5));
        walk.finish();
        async.elapse(const Duration(hours: 1));
        expect(walk.phase, WalkPhase.idle);
        expect(location.holds, isEmpty);
        expect(sms.attempts, isEmpty);
      }));

  test('missing the deadline asks first and sounds the alarm', () => run((async) {
        startWalk(async);
        async.elapse(const Duration(minutes: 10, seconds: 1));
        expect(walk.phase, WalkPhase.checkIn);
        expect(alarm.isPlaying, isTrue);
        expect(sms.attempts, isEmpty);
      }));

  test("answering I'm safe at the check-in prevents the SOS", () => run((async) {
        startWalk(async);
        async.elapse(const Duration(minutes: 10, seconds: 30));
        walk.finish();
        async.elapse(const Duration(minutes: 5));
        expect(alarm.isPlaying, isFalse);
        expect(sms.attempts, isEmpty);
        expect(emergency.phase, EmergencyPhase.idle);
      }));

  test('no answer fires the SOS automatically', () => run((async) {
        startWalk(async);
        async.elapse(const Duration(minutes: 11, seconds: 2));
        expect(walk.phase, WalkPhase.idle);
        expect(emergency.phase, EmergencyPhase.active);
        expect(sms.sent.single.message, startsWith('SOS!'));
      }));

  test('extending from the check-in gives more time', () => run((async) {
        startWalk(async);
        async.elapse(const Duration(minutes: 10, seconds: 30));
        walk.extend(const Duration(minutes: 10));
        async.elapse(const Duration(minutes: 9));
        expect(walk.phase, WalkPhase.walking);
        expect(alarm.isPlaying, isFalse);
        expect(sms.attempts, isEmpty);
      }));

  test('a restart keeps the walk running', () => run((async) {
        startWalk(async);
        async.elapse(const Duration(minutes: 2));
        final restarted = build();
        restarted.resumeIfActive();
        async.flushMicrotasks();
        expect(restarted.phase, WalkPhase.walking);
        expect(restarted.destination, 'Home');
      }));

  test('being killed past the deadline still ends in an SOS', () => run((async) {
        StorageService().saveSafeWalk({
          'deadline': clock
              .now()
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
          'destination': '',
        });
        async.flushMicrotasks();
        walk.resumeIfActive();
        async.elapse(const Duration(seconds: 2));
        expect(emergency.phase, EmergencyPhase.active);
        expect(sms.sent, hasLength(1));
      }));

  test('contacts can be told the walk started', () => run((async) {
        startWalk(async, notify: true);
        expect(sms.sent.single.message, contains('Safe Walk to Home'));
      }));
}
