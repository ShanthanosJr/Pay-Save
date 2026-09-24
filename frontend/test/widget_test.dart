import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pay_and_save/core/auth/auth_controller.dart';
import 'package:pay_and_save/main.dart';

import 'support/fakes.dart';

Future<(WidgetTester, FakeAuthApi, MemoryTokenStore)> pumpApp(
  WidgetTester tester, {
  bool signedIn = false,
}) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final api = FakeAuthApi();
  final store = MemoryTokenStore();
  if (signedIn) store.tokens = testTokens;

  await tester.pumpWidget(ProviderScope(
    overrides: [
      authApiProvider.overrideWithValue(api),
      tokenStoreProvider.overrideWithValue(store),
    ],
    child: const PayAndSaveApp(),
  ));
  await tester.pumpAndSettle();
  return (tester, api, store);
}

void main() {
  testWidgets('Welcome shows brand, language chips and both entry buttons', (tester) async {
    await pumpApp(tester);
    expect(find.text('Pay&Save'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('සිංහල'), findsOneWidget);
  });

  testWidgets('Switching language on Welcome changes the copy live', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('සිංහල'));
    await tester.pumpAndSettle();
    expect(find.text('ඇතුළු වන්න'), findsOneWidget);
    expect(find.text('Log in'), findsNothing);
  });

  testWidgets('Login with phone + password signs in and lands on Home', (tester) async {
    final (_, api, store) = await pumpApp(tester);
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '077 123 4567');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.widgetWithText(InkWell, 'Log in').last);
    await tester.pumpAndSettle();

    expect(api.lastLoginIdentifier, '+94771234567');
    expect(store.tokens, isNotNull);
    expect(find.text('Hello, Nadeeshi'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Login with email normalises to lower case', (tester) async {
    final (_, api, _) = await pumpApp(tester);
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Me@Example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.widgetWithText(InkWell, 'Log in').last);
    await tester.pumpAndSettle();

    expect(api.lastLoginIdentifier, 'me@example.com');
  });

  testWidgets('Wrong credentials show an error and stay on Login', (tester) async {
    final (_, api, store) = await pumpApp(tester);
    api.loginFails = true;
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'me@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass1');
    await tester.tap(find.widgetWithText(InkWell, 'Log in').last);
    await tester.pumpAndSettle();

    expect(find.text('Incorrect phone, email or password'), findsOneWidget);
    expect(store.tokens, isNull);
  });

  testWidgets('Empty login shows validation and does not call the API', (tester) async {
    final (_, api, _) = await pumpApp(tester);
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Log in').last);
    await tester.pumpAndSettle();

    expect(find.text('Enter your phone number or email'), findsOneWidget);
    expect(api.lastLoginIdentifier, isNull);
  });

  testWidgets('Stored session restores straight to Home', (tester) async {
    await pumpApp(tester, signedIn: true);
    expect(find.text('Hello, Nadeeshi'), findsOneWidget);
  });

  testWidgets('Full registration: details, phone OTP, credentials, then Home', (tester) async {
    final (_, api, store) = await pumpApp(tester);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    // Step 1: invalid details are rejected
    await tester.tap(find.widgetWithText(InkWell, 'Continue').last);
    await tester.pumpAndSettle();
    expect(find.text('This field is required'), findsWidgets);

    await tester.enterText(find.byType(TextFormField).at(0), 'Nadeeshi Perera');
    await tester.enterText(find.byType(TextFormField).at(1), '29');
    await tester.enterText(find.byType(TextFormField).at(2), '200012345678');
    await tester.tap(find.widgetWithText(InkWell, 'Continue').last);
    await tester.pumpAndSettle();

    // Step 2: phone, then OTP
    expect(find.text('Step 2 of 3'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '0771234567');
    await tester.tap(find.widgetWithText(InkWell, 'Send code').last);
    await tester.pumpAndSettle();
    expect(api.calls, contains('otp:+94771234567'));
    expect(find.text('Code sent to +94771234567'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();
    expect(api.calls, contains('verify:123456'));

    // Step 3: email + password
    expect(find.text('Step 3 of 3'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Nadeeshi@Example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'abcd1234');
    await tester.enterText(find.byType(TextFormField).at(2), 'abcd1234');
    await tester.tap(find.widgetWithText(InkWell, 'Create account').last);
    await tester.pumpAndSettle();

    expect(api.lastRegister, {
      'fullName': 'Nadeeshi Perera',
      'age': 29,
      'nic': '200012345678',
      'phone': '+94771234567',
      'email': 'nadeeshi@example.com',
      'password': 'abcd1234',
      'token': 'phone-token',
    });
    expect(store.tokens, isNotNull);
    expect(find.text('Hello, Nadeeshi'), findsOneWidget);
  });

  testWidgets('Wrong OTP shows an error and stays on the code step', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Nadeeshi Perera');
    await tester.enterText(find.byType(TextFormField).at(1), '29');
    await tester.enterText(find.byType(TextFormField).at(2), '901234567V');
    await tester.tap(find.widgetWithText(InkWell, 'Continue').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0771234567');
    await tester.tap(find.widgetWithText(InkWell, 'Send code').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '000000');
    await tester.pumpAndSettle();

    expect(find.text('That code is incorrect or has expired'), findsOneWidget);
    expect(find.text('Step 2 of 3'), findsOneWidget);
  });

  testWidgets('Profile shows masked details and verifies email by OTP', (tester) async {
    final (_, api, _) = await pumpApp(tester, signedIn: true);
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();

    expect(find.text('Nadeeshi Perera'), findsOneWidget);
    expect(find.text('+9477*****21'), findsOneWidget);
    expect(find.text('nadeeshi@example.com'), findsOneWidget);

    await tester.tap(find.text('Verify email'));
    await tester.pumpAndSettle();
    expect(find.text('Verify your email'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '654321');
    await tester.pumpAndSettle();
    expect(api.emailVerified, isTrue);
    expect(find.text('Email verified'), findsOneWidget);
  });

  testWidgets('Log out returns to Welcome and clears tokens', (tester) async {
    final (_, _, store) = await pumpApp(tester, signedIn: true);
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Log out'));
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(store.tokens, isNull);
    expect(find.text('Create account'), findsOneWidget);
  });
}
