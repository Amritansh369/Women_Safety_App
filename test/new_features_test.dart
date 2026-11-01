import 'dart:convert';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:women_safety_app/models/app_settings.dart';
import 'package:women_safety_app/models/incident.dart';
import 'package:women_safety_app/models/location_fix.dart';
import 'package:women_safety_app/screens/nearby_screen.dart';
import 'package:women_safety_app/services/emergency_controller.dart';
import 'package:women_safety_app/services/nearby_service.dart';
import 'package:women_safety_app/services/safe_walk_controller.dart';
import 'package:women_safety_app/services/sms_service.dart';
import 'package:women_safety_app/services/sos_service.dart';
import 'package:women_safety_app/services/storage_service.dart';
import 'package:women_safety_app/strings.dart';
import 'fakes.dart';

const asha = '+919800000001';
const meera = '+919800000002';
const home = LatLng(12.9716, 77.5946);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void seed({String? settings}) {
    SharedPreferences.setMockInitialValues({
      'emergency_contacts': [
        for (final phone in [asha, meera])
          jsonEncode({
            'id': phone,
            'name': 'Contact $phone',
            'phone': phone,
            'relation': 'Friend',
          }),
      ],
      'profile_name': 'Priya',
      'app_settings': ?settings,
    });
  }

  setUp(seed);

  group('alert languages', () {
    final now = DateTime(2026, 11, 1, 21, 30);
    final fix = fixAt(now);

    test('every language has every message and fills every placeholder', () {
      for (final language in alertLanguages.keys) {
        final messages = [
          SosMessages.alert(
            name: 'Priya',
            fix: fix,
            now: now,
            bloodGroup: 'O+',
            customMessage: 'Help',
            destination: 'Home',
            language: language,
          ),
          SosMessages.alert(name: '', fix: null, now: now, language: language),
          SosMessages.update(fix: fix, now: now, language: language),
          SosMessages.allClear('Priya', language: language),
          SosMessages.test('Priya', language: language),
          SosMessages.walkStarted('Priya', 'Home', now, language: language),
          SosMessages.walkArrived('Priya', language: language),
          SosMessages.lowBattery(
            name: 'Priya',
            level: 9,
            fix: fix,
            now: now,
            language: language,
          ),
        ];
        for (final message in messages) {
          expect(message, isNot(contains('{')), reason: '$language: $message');
        }
        expect(messages.first, contains(fix.mapsLink));
        expect(messages.first, contains('SOS'));
      }
    });

    test('non-English alerts really are translated', () {
      final hindi = SosMessages.allClear('Priya', language: 'hi');
      expect(hindi, contains('सुरक्षित'));
    });

    test('an unknown language falls back to English', () {
      expect(
        SosMessages.alert(name: 'Priya', fix: null, now: now, language: 'xx'),
        contains('needs help now'),
      );
    });

    test('SOS screens switch to Hindi and fill in values', () {
      addTearDown(() => appLanguage = 'en');
      appLanguage = 'hi';
      expect(tr('Delivered'), 'पहुँच गया');
      expect(tr('Call {number}', {'number': '112'}), contains('112'));
    });

    test('the alert uses the chosen language', () => fakeAsync((async) {
          seed(settings: jsonEncode(const AppSettings(language: 'hi').toJson()));
          final sms = FakeSms();
          final controller = EmergencyController(
            sms: sms,
            location: FakeLocation()..current = freshFix(),
            storage: StorageService(),
            siren: FakeSiren(),
          );
          controller.triggerNow(IncidentTrigger.button);
          async.elapse(const Duration(seconds: 1));
          expect(sms.sent.first.message, contains('मदद चाहिए'));
        }));
  });

  group('delivery reports', () {
    test('marks only the confirmed contact, and persists it', () => fakeAsync((async) {
          final sms = FakeSms();
          final controller = EmergencyController(
            sms: sms,
            location: FakeLocation()..current = freshFix(),
            storage: StorageService(),
            siren: FakeSiren(),
          );
          controller.triggerNow(IncidentTrigger.button);
          async.elapse(const Duration(seconds: 1));

          final tag = sms.deliveryTags.firstWhere((t) => t.endsWith(asha));
          sms.deliveryReports.add(tag);
          async.elapse(const Duration(seconds: 1));

          final alerts = controller.incident!.alerts;
          expect(alerts.firstWhere((a) => a.phone == asha).delivered, isTrue);
          expect(alerts.firstWhere((a) => a.phone == meera).delivered, isFalse);

          StorageService().getActiveIncident().then((saved) {
            expect(
              saved!.alerts.firstWhere((a) => a.phone == asha).delivered,
              isTrue,
            );
          });
          async.flushMicrotasks();
        }));

    test('a contact with no report is still "sent", never "failed"',
        () => fakeAsync((async) {
          final controller = EmergencyController(
            sms: FakeSms(),
            location: FakeLocation()..current = freshFix(),
            storage: StorageService(),
            siren: FakeSiren(),
          );
          controller.triggerNow(IncidentTrigger.button);
          async.elapse(const Duration(seconds: 1));
          expect(controller.incident!.countWhere(AlertStatus.sent), 2);
        }));

    test('old saved alerts without the field still load', () {
      final alert = ContactAlert.fromJson(
        {'contactId': '1', 'name': 'A', 'phone': '1', 'status': 'sent'},
      );
      expect(alert.delivered, isFalse);
    });
  });

  group('contacts reached through the messaging app', () {
    late FakeSms sms;
    late EmergencyController controller;

    void activate(FakeAsync async) {
      sms = FakeSms()..alwaysReturn = SmsResult.noPermission;
      controller = EmergencyController(
        sms: sms,
        location: FakeLocation()..current = freshFix(),
        storage: StorageService(),
        siren: FakeSiren(),
      );
      controller.triggerNow(IncidentTrigger.button);
      async.elapse(const Duration(seconds: 1));
      expect(sms.composerCalls, hasLength(1));
    }

    test('scheduled updates never open the messaging app by themselves',
        () => fakeAsync((async) {
              activate(async);
              async.elapse(const Duration(minutes: 20));
              expect(sms.composerCalls, hasLength(1));
            }));

    test('the user can send them an update', () => fakeAsync((async) {
          activate(async);
          late bool opened;
          controller.sendManualUpdate().then((value) => opened = value);
          async.flushMicrotasks();
          expect(opened, isTrue);
          expect(sms.composerCalls.last, unorderedEquals([asha, meera]));
          expect(sms.composerMessages.last, contains('update'));
        }));

    test('"I\'m safe" reaches them too', () => fakeAsync((async) {
          activate(async);
          controller.markSafe();
          async.elapse(const Duration(seconds: 1));
          expect(sms.composerMessages.last, contains('marked themselves safe'));
          expect(controller.phase, EmergencyPhase.idle);
        }));
  });

  group('Safe Walk arrival and battery', () {
    late FakeSms sms;
    late FakeLocation location;
    late SafeWalkController walk;
    late int arrivals;
    int? battery;

    void build() {
      sms = FakeSms();
      location = FakeLocation();
      arrivals = 0;
      battery = null;
      walk = SafeWalkController(
        emergency: EmergencyController(
          sms: sms,
          location: location,
          storage: StorageService(),
          siren: FakeSiren(),
        ),
        location: location,
        storage: StorageService(),
        sms: sms,
        alarm: FakeSiren(),
        batteryLevel: () async => battery,
        onArrived: () => arrivals++,
      );
    }

    LocationFix at(LatLng point, {double accuracy = 12}) => LocationFix(
          latitude: point.latitude,
          longitude: point.longitude,
          accuracy: accuracy,
          time: clock.now(),
        );

    void start(FakeAsync async, {bool notify = true}) {
      walk.start(
        duration: const Duration(minutes: 20),
        notifyContacts: notify,
        arrivalPoint: home,
      );
      async.flushMicrotasks();
    }

    test('ends the walk once the user stays at the arrival point',
        () => fakeAsync((async) {
              build();
              start(async);
              location.stream.add(at(home));
              async.elapse(const Duration(seconds: 10));
              expect(walk.phase, WalkPhase.walking);
              async.elapse(const Duration(seconds: 25));

              expect(walk.phase, WalkPhase.idle);
              expect(arrivals, 1);
              expect(
                sms.sent.where((s) => s.message.contains('reached')),
                hasLength(2),
              );
            }));

    test('passing through does not end it', () => fakeAsync((async) {
          build();
          start(async);
          location.stream.add(at(home));
          async.elapse(const Duration(seconds: 10));
          location.stream.add(at(const LatLng(12.99, 77.60)));
          async.elapse(const Duration(minutes: 2));
          expect(walk.phase, WalkPhase.walking);
        }));

    test('a vague fix does not count as arriving', () => fakeAsync((async) {
          build();
          start(async);
          location.stream.add(at(home, accuracy: 400));
          async.elapse(const Duration(minutes: 2));
          expect(walk.phase, WalkPhase.walking);
        }));

    test('tells nobody if they were not told about the walk',
        () => fakeAsync((async) {
              build();
              start(async, notify: false);
              location.stream.add(at(home));
              async.elapse(const Duration(seconds: 40));
              expect(walk.phase, WalkPhase.idle);
              expect(sms.sent, isEmpty);
            }));

    test('a walk with an arrival point survives a restart', () => fakeAsync((async) {
          build();
          start(async);
          build();
          walk.resumeIfActive();
          async.flushMicrotasks();
          expect(walk.detectsArrival, isTrue);
          location.stream.add(at(home));
          async.elapse(const Duration(seconds: 40));
          expect(walk.phase, WalkPhase.idle);
        }));

    test('warns contacts once when the battery runs low', () => fakeAsync((async) {
          build();
          location.current = freshFix();
          start(async, notify: false);
          async.elapse(const Duration(minutes: 2));
          expect(sms.sent, isEmpty);

          battery = 9;
          async.elapse(const Duration(minutes: 5));
          final warnings = sms.sent.where((s) => s.message.contains('9%'));
          expect(warnings, hasLength(2));
          expect(warnings.first.message, contains('maps.google.com'));
        }));

    test('tries again if the battery warning reached nobody', () => fakeAsync((async) {
          build();
          location.current = freshFix();
          start(async, notify: false);
          battery = 5;
          sms.alwaysReturn = SmsResult.failed;
          async.elapse(const Duration(minutes: 2));
          sms.alwaysReturn = null;
          async.elapse(const Duration(minutes: 3));
          expect(sms.sent.where((s) => s.message.contains('5%')), hasLength(2));
        }));
  });

  group('Nearby Help', () {
    const police = '''
[{"name":"MG Road Police","lat":"12.97","lon":"77.59",
  "extratags":{"phone":"080 1234; 080 5678"}},
 {"name":"","lat":"12.98","lon":"77.60","extratags":null}]''';
    const hospital = '''
[{"name":"City Hospital","lat":"12.98","lon":"77.60","extratags":null}]''';
    const photon = '''
{"features":[
 {"geometry":{"coordinates":[77.6,12.98]},"properties":{"name":"Photon Place"}},
 {"geometry":{"coordinates":[77.7,12.99]},"properties":{}}]}''';

    http.Response nominatimReply(http.Request request) => http.Response(
          request.url.queryParameters['amenity'] == 'police' ? police : hospital,
          200,
        );

    NearbyService service(MockClientHandler handler) => NearbyService(
          client: MockClient(handler),
          politeDelay: Duration.zero,
        );

    test('reads results, and skips unnamed entries', () {
      final places = NearbyService.parseNominatim(police, PlaceKind.police);
      expect(places.map((p) => p.name), ['MG Road Police']);
      expect(places.single.phone, '080 1234');
      expect(places.single.latitude, 12.97);

      final backup = NearbyService.parsePhoton(photon, PlaceKind.hospital);
      expect(backup.map((p) => p.name), ['Photon Place']);
      expect(backup.single.latitude, 12.98);
      expect(backup.single.longitude, 77.6);
    });

    test('finds police and hospitals within the search area', () async {
      final asked = <Uri>[];
      final result = await service((request) async {
        asked.add(request.url);
        return nominatimReply(request);
      }).find(12.97, 77.59);

      expect(result!.places.map((p) => p.kind),
          [PlaceKind.police, PlaceKind.hospital]);
      expect(result.fromCache, isFalse);
      final box = asked.first.queryParameters['viewbox']!
          .split(',')
          .map(double.parse)
          .toList();
      expect(box[0], lessThan(77.59));
      expect(box[1], greaterThan(12.97));
      expect(box[2], greaterThan(77.59));
      expect(box[3], lessThan(12.97));
    });

    test('uses the backup service when the first is down', () async {
      final result = await service((request) async {
        if (request.url.host.startsWith('nominatim')) {
          return http.Response('down', 502);
        }
        return http.Response(photon, 200);
      }).find(12.97, 77.59);
      expect(result!.places.map((p) => p.name).toSet(), {'Photon Place'});
      expect(result.fromCache, isFalse);
    });

    test('offline, shows the last saved search, marked as saved', () async {
      var online = true;
      final nearby = service((request) async {
        if (!online) throw http.ClientException('no signal');
        return nominatimReply(request);
      });
      await nearby.find(12.97, 77.59);
      online = false;
      final result = await nearby.find(12.97, 77.59);
      expect(result!.fromCache, isTrue);
      expect(result.places, hasLength(2));
    });

    test('offline with nothing saved reports nothing', () async {
      final nearby =
          service((_) async => throw http.ClientException('no signal'));
      expect(await nearby.find(12.97, 77.59), isNull);
    });

    test('a damaged saved search counts as nothing saved', () async {
      SharedPreferences.setMockInitialValues({'nearby_places': '{"oops":1}'});
      expect(await NearbyService().saved(), isNull);
    });

    testWidgets('never stays on the spinner', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NearbyScreen(
          service: service((_) async => throw http.ClientException('down')),
          locate: () async => throw Exception('GPS failed'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('shows places, nearest first', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NearbyScreen(
          service: service((request) async => nominatimReply(request)),
          locate: () async => LocationFix(
            latitude: 12.98,
            longitude: 77.60,
            accuracy: 10,
            time: DateTime(2026),
          ),
        ),
      ));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      final hospitalTop = tester.getTopLeft(find.text('City Hospital')).dy;
      final policeTop = tester.getTopLeft(find.text('MG Road Police')).dy;
      expect(hospitalTop, lessThan(policeTop));
    });
  });
}
