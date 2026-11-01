import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:women_safety_app/screens/contacts_screen.dart';
import 'package:women_safety_app/services/storage_service.dart';

void main() {
  const channel = MethodChannel('flutter_native_contact_picker');
  late Future<Object?> Function() onPick;

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      expect(call.method, 'selectPhoneNumber');
      return onPick();
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Map<String, Object> contact(String name, String number) => {
        'fullName': name,
        'phoneNumbers': [number],
        'selectedPhoneNumber': number,
      };

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ContactsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add contact'));
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester) async {
    await tester.tap(find.text('Choose from phone contacts'));
    await tester.pumpAndSettle();
  }

  testWidgets('a picked contact fills the form and saves cleaned', (tester) async {
    onPick = () async => contact('Meera Rao', '+91 98000-00002');
    await openDialog(tester);
    await pick(tester);
    expect(find.text('Meera Rao'), findsOneWidget);
    expect(find.text('+919800000002'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = await tester.runAsync(() => StorageService().getContacts());
    expect(saved!.last.name, 'Meera Rao');
    expect(saved.last.phone, '+919800000002');
    expect(saved.last.relation, 'Contact');
  });

  testWidgets('backing out of the picker keeps what was typed', (tester) async {
    onPick = () async => null;
    await openDialog(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Typed');
    await pick(tester);
    expect(find.text('Typed'), findsOneWidget);
  });

  testWidgets('if the picker fails, the form can still be typed in', (tester) async {
    onPick = () async => throw PlatformException(code: 'intent_error');
    await openDialog(tester);
    await pick(tester);
    expect(find.textContaining("Couldn't open your contacts"), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Name'), findsOneWidget);
  });

  testWidgets('a contact with no usable number cannot be saved', (tester) async {
    onPick = () async => contact('Landline', '12');
    await openDialog(tester);
    await pick(tester);
    expect(find.text('Enter a valid phone number'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = await tester.runAsync(() => StorageService().getContacts());
    expect(saved, hasLength(1));
  });

  testWidgets('the same person cannot be added twice', (tester) async {
    onPick = () async => contact('Asha New', '098000 00001');
    await openDialog(tester);
    await pick(tester);
    expect(find.text('This number is already in your contacts'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = await tester.runAsync(() => StorageService().getContacts());
    expect(saved, hasLength(1));
  });

  testWidgets('editing a contact does not clash with itself', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ContactsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Contact'), findsNothing);
  });

  test('isSameNumber ignores formatting and prefixes', () {
    expect(isSameNumber('+919800000001', '09800000001'), isTrue);
    expect(isSameNumber('+91 98000 00001', '9800000001'), isTrue);
    expect(isSameNumber('+919800000001', '+919800000002'), isFalse);
  });
}
