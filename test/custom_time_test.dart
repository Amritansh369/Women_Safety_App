import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/screens/fake_call_screen.dart';
import 'package:women_safety_app/screens/safe_walk_screen.dart';
import 'package:women_safety_app/widgets/custom_time_dialog.dart';

void main() {
  test('shortDuration reads naturally', () {
    expect(shortDuration(const Duration(minutes: 85)), '1 h 25 min');
    expect(shortDuration(const Duration(minutes: 25)), '25 min');
    expect(shortDuration(const Duration(hours: 8)), '8 h');
    expect(shortDuration(const Duration(seconds: 150)), '2 min 30 sec');
    expect(shortDuration(const Duration(seconds: 45)), '45 sec');
  });

  group('dialog', () {
    Duration? result;

    Future<void> open(WidgetTester tester, {Duration? initial}) async {
      result = null;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showCustomTimeDialog(
                context,
                title: 'Pick',
                largeLabel: 'Hours',
                smallLabel: 'Minutes',
                largeUnit: const Duration(hours: 1),
                smallUnit: const Duration(minutes: 1),
                max: const Duration(hours: 8),
                initial: initial,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    Future<void> enter(WidgetTester tester, String label, String value) =>
        tester.enterText(find.widgetWithText(TextField, label), value);

    testWidgets('combines both fields', (tester) async {
      await open(tester);
      await enter(tester, 'Hours', '1');
      await enter(tester, 'Minutes', '25');
      await tester.tap(find.text('Set time'));
      await tester.pumpAndSettle();
      expect(result, const Duration(minutes: 85));
    });

    testWidgets('accepts either field alone', (tester) async {
      await open(tester);
      await enter(tester, 'Minutes', '7');
      await tester.tap(find.text('Set time'));
      await tester.pumpAndSettle();
      expect(result, const Duration(minutes: 7));
    });

    testWidgets('refuses an empty or zero time', (tester) async {
      await open(tester);
      await enter(tester, 'Minutes', '0');
      await tester.tap(find.text('Set time'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a time'), findsOneWidget);
      expect(result, isNull);
    });

    testWidgets('refuses more than the maximum', (tester) async {
      await open(tester);
      await enter(tester, 'Hours', '8');
      await enter(tester, 'Minutes', '1');
      await tester.tap(find.text('Set time'));
      await tester.pumpAndSettle();
      expect(find.text('Choose 8 h or less'), findsOneWidget);
      expect(result, isNull);
    });

    testWidgets('only allows digits', (tester) async {
      await open(tester);
      await enter(tester, 'Minutes', '-5a');
      await tester.tap(find.text('Set time'));
      await tester.pumpAndSettle();
      expect(result, const Duration(minutes: 5));
    });

    testWidgets('shows the current custom time when reopened', (tester) async {
      await open(tester, initial: const Duration(minutes: 85));
      expect(find.widgetWithText(TextField, '1'), findsOneWidget);
      expect(find.widgetWithText(TextField, '25'), findsOneWidget);
    });

    testWidgets('cancel changes nothing', (tester) async {
      await open(tester);
      await enter(tester, 'Minutes', '12');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });

  testWidgets('Fake Call shows a custom delay on its chip', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FakeCallScreen()));
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Minutes'), '2');
    await tester.enterText(find.widgetWithText(TextField, 'Seconds'), '30');
    await tester.tap(find.text('Set time'));
    await tester.pumpAndSettle();
    expect(find.text('2 min 30 sec'), findsOneWidget);
    expect(find.text('Custom'), findsNothing);

    await tester.tap(find.text('10 sec'));
    await tester.pumpAndSettle();
    expect(find.text('Custom'), findsOneWidget);
  });

  testWidgets('Safe Walk shows a custom time on its chip', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SafeWalkScreen()));
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Hours'), '1');
    await tester.enterText(find.widgetWithText(TextField, 'Minutes'), '25');
    await tester.tap(find.text('Set time'));
    await tester.pumpAndSettle();
    expect(find.text('1 h 25 min'), findsOneWidget);
  });
}
