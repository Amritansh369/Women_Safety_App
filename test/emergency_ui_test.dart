import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:women_safety_app/models/incident.dart';
import 'package:women_safety_app/screens/emergency_screen.dart';
import 'package:women_safety_app/services/emergency_controller.dart';
import 'package:women_safety_app/services/sms_service.dart';
import 'package:women_safety_app/services/storage_service.dart';
import 'package:women_safety_app/widgets/hold_button.dart';
import 'fakes.dart';

void main() {
  late FakeSms sms;
  late EmergencyController controller;

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
    sms = FakeSms();
    controller = EmergencyController(
      sms: sms,
      location: FakeLocation(),
      storage: StorageService(),
      siren: FakeSiren(),
    );
    EmergencyController.instance = controller;
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: EmergencyScreen()));
  }

  Future<void> activate(WidgetTester tester) async {
    await tester.runAsync(() async {
      await controller.startCountdown(IncidentTrigger.button);
      await controller.sendNowDuringCountdown();
    });
    await tester.pump();
  }

  testWidgets('countdown shows the seconds and can be cancelled', (tester) async {
    await pumpScreen(tester);
    await tester.runAsync(
      () => controller.startCountdown(IncidentTrigger.button),
    );
    await tester.pump();
    expect(find.text('5'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(controller.phase, EmergencyPhase.idle);
  });

  testWidgets('says SENT only when the network accepted it', (tester) async {
    await pumpScreen(tester);
    await activate(tester);
    expect(find.text('SOS sent to 1 of 1'), findsOneWidget);
  });

  testWidgets('tells the user when they still have to press send', (tester) async {
    sms.alwaysReturn = SmsResult.noPermission;
    await pumpScreen(tester);
    await activate(tester);
    expect(find.text('Press send in your messages app'), findsOneWidget);
    expect(find.textContaining('NOT been sent'), findsOneWidget);
    expect(find.textContaining('SOS sent'), findsNothing);
  });

  testWidgets('offers a retry and the emergency number after failure', (tester) async {
    sms.alwaysReturn = SmsResult.unsupported;
    sms.composerOpens = false;
    await pumpScreen(tester);
    await activate(tester);
    expect(find.text('SOS not sent yet'), findsOneWidget);
    expect(find.textContaining('Retrying automatically'), findsOneWidget);
    expect(find.text('Retry 1 failed'), findsOneWidget);
    expect(find.text('Call 112'), findsOneWidget);
  });

  group('HoldButton', () {
    Widget button(VoidCallback onConfirmed) => MaterialApp(
          home: Center(
            child: HoldButton(
              onConfirmed: onConfirmed,
              semanticLabel: 'Start SOS countdown',
              color: Colors.red,
              child: const Text('SOS'),
            ),
          ),
        );

    testWidgets('a quick tap does nothing', (tester) async {
      var fired = 0;
      await tester.pumpWidget(button(() => fired++));
      final gesture = await tester.startGesture(tester.getCenter(find.text('SOS')));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fired, 0);
    });

    testWidgets('holding for the full time fires once', (tester) async {
      var fired = 0;
      await tester.pumpWidget(button(() => fired++));
      final gesture = await tester.startGesture(tester.getCenter(find.text('SOS')));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fired, 1);
    });

    testWidgets('screen readers can activate it without holding', (tester) async {
      var fired = 0;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(button(() => fired++));
      tester.semantics.tap(find.semantics.byLabel('Start SOS countdown'));
      expect(fired, 1);
      handle.dispose();
    });
  });
}
