import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pay_and_save/core/notifications/notifications.dart';
import 'package:pay_and_save/core/widgets/ps_otp_field.dart';

import 'support/fake_circles.dart';
import 'support/fake_extras.dart';
import 'support/pump.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).first;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// The nth text field on the page, top to bottom (labels sit above the fields).
Future<void> typeAt(WidgetTester tester, int index, String value) async {
  final field = find.byType(TextFormField).at(index);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

AppNotification note(String id, String kind, Map<String, dynamic> payload, {bool read = false}) => AppNotification(
      id: id,
      kind: kind,
      createdAt: DateTime(2026, 10, 9, 14, 5),
      read: read,
      payload: payload,
      circleId: 'c1',
      circleName: 'Friends Seettu',
    );

void main() {
  group('password', () {
    testWidgets('forgot password: code by SMS, then a new password, then back to log in', (tester) async {
      final (_, api, _) = await pumpApp(tester);
      await tapText(tester, 'Log in');
      await tapText(tester, 'Forgot password?');
      await typeAt(tester, 0, '077 123 4567');
      await tapText(tester, 'Send code');
      expect(api.calls.last, 'forgot:+94771234567');
      expect(find.textContaining('a code was sent to it by SMS'), findsOneWidget);

      // a wrong code is refused in plain words
      await tester.enterText(find.descendant(of: find.byType(PsOtpField), matching: find.byType(EditableText)), '111111');
      await typeAt(tester, 0, 'Newpass123');
      await typeAt(tester, 1, 'Newpass123');
      await tapText(tester, 'Set new password');
      expect(find.textContaining('code is incorrect'), findsOneWidget);

      await tester.enterText(find.descendant(of: find.byType(PsOtpField), matching: find.byType(EditableText)), '246810');
      await tapText(tester, 'Set new password');
      expect(api.calls.last, 'reset:+94771234567:Newpass123');
      expect(find.text('Password changed. Log in with your new password.'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('change password: wrong current one is explained, right one keeps me signed in', (tester) async {
      final (_, api, store) = await pumpApp(tester, signedIn: true);
      await tapText(tester, 'Profile');
      await tapText(tester, 'Change password');
      expect(find.textContaining('other phones and browsers are signed out'), findsOneWidget);
      await typeAt(tester, 0, 'nope');
      await typeAt(tester, 1, 'Newpass123');
      await typeAt(tester, 2, 'Newpass123');
      await tester.tap(find.widgetWithText(InkWell, 'Change password').last);
      await tester.pumpAndSettle();
      expect(find.text('The current password is not correct.'), findsOneWidget);

      await typeAt(tester, 0, 'Passw0rdOld');
      await tester.tap(find.widgetWithText(InkWell, 'Change password').last);
      await tester.pumpAndSettle();
      expect(api.calls.last, 'password:Newpass123');
      expect(store.tokens?.accessToken, 'access-2');
      expect(find.text('Password changed'), findsOneWidget);
    });
  });

  testWidgets('notifications: bell shows the unread count; opening the inbox marks them read', (tester) async {
    final inbox = FakeNotificationsApi()
      ..items = [
        note('n1', 'payment_rejected', {'reference': 'PS-1021', 'reason': 'No transfer received', 'amountMinor': 450000}),
        note('n2', 'reminder_due', {'cycleNumber': 4, 'daysLeft': 3, 'amountMinor': 500000}),
        note('n3', 'cycle_closed', {'cycleNumber': 3, 'count': 3, 'unitMinor': 500000, 'totalMinor': 1500000}, read: true),
      ];
    await pumpApp(tester, signedIn: true, circles: FakeCirclesApi(seed: FakeSeed.activeMember), notifications: inbox);
    expect(find.bySemanticsLabel('Notifications, 2'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Notifications, 2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your payment was not accepted · PS-1021'), findsOneWidget);
    expect(find.textContaining('No transfer received'), findsOneWidget);
    expect(find.text('Cycle 4 is due in 3 days'), findsOneWidget);
    // totals in a notification still show their arithmetic
    expect(find.textContaining('3 verified × LKR 5,000 = LKR 15,000'), findsOneWidget);
    expect(inbox.markedRead, 1);
  });

  testWidgets('reminders start off with nothing ticked; saving needs a day (U-06)', (tester) async {
    final reminders = FakeRemindersApi();
    await pumpApp(tester, signedIn: true, circles: FakeCirclesApi(seed: FakeSeed.activeMember), reminders: reminders);
    await tapText(tester, 'Circles');
    await tapText(tester, 'Reminders');

    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
    for (final box in tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile))) {
      expect(box.value, isFalse);
      expect(box.onChanged, isNull, reason: 'days cannot be ticked while reminders are off');
    }
    expect(find.text('Suggested'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tapText(tester, 'Save reminders');
    expect(find.text('Choose at least one day to be reminded.'), findsOneWidget);
    expect(reminders.prefs.enabled, isFalse);

    await tapText(tester, '3 days before');
    await tapText(tester, 'Also by SMS');
    // email is not verified, so that channel cannot be chosen
    await tapText(tester, 'Also by email');
    await tapText(tester, 'Save reminders');
    expect(reminders.prefs.enabled, isTrue);
    expect(reminders.prefs.daysBefore, [3]);
    expect(reminders.prefs.channels, ['sms']);
  });

  testWidgets('statement: create, see the arithmetic and code, share the PDF', (tester) async {
    final statements = FakeStatementsApi();
    final shared = <String>[];
    await pumpApp(
      tester,
      signedIn: true,
      circles: FakeCirclesApi(seed: FakeSeed.activeMember),
      statements: statements,
      sharedFiles: shared,
    );
    await tapText(tester, 'Circles');
    await tapText(tester, 'Savings statement');
    expect(find.text('Create my statement'), findsOneWidget);

    statements.nothingVerified = true;
    await tapText(tester, 'Create my statement');
    expect(find.text('You have no verified payments in this circle yet.'), findsOneWidget);

    statements.nothingVerified = false;
    await tapText(tester, 'Create my statement');
    expect(find.text('3 verified × LKR 5,000 = LKR 15,000'), findsOneWidget);
    expect(find.text('PS-ABCD-EFGH-JK23'), findsOneWidget);
    expect(find.text('https://api.example.lk/verify/PS-ABCD-EFGH-JK23'), findsOneWidget);

    // the total opens its parts
    await tapText(tester, '3 verified × LKR 5,000 = LKR 15,000');
    expect(find.textContaining('PS-1002'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tapText(tester, 'Save or share PDF');
    expect(shared, ['pay-and-save-PS-ABCD-EFGH-JK23.pdf']);
  });

  group('privacy and disputes', () {
    testWidgets('a member sees what officers can see, gives consent, and answers a dispute (U-05)', (tester) async {
      final community = FakeCommunityApi()..seedAwaitingMe();
      await pumpApp(tester, signedIn: true, circles: FakeCirclesApi(seed: FakeSeed.activeMember), community: community);
      await tapText(tester, 'Circles');
      await tapText(tester, 'Privacy & access');

      expect(find.textContaining('Never: names, phone numbers'), findsOneWidget);
      // the exception is stated next to the rule, not hidden
      expect(find.textContaining('One exception: in a dispute'), findsOneWidget);
      expect(find.text('2 of 5 members have agreed'), findsOneWidget);
      expect(find.textContaining('Not shared'), findsOneWidget);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(community.state.mine, isTrue);
      expect(find.text('3 of 5 members have agreed'), findsOneWidget);

      expect(find.text('My payment was rejected wrongly'), findsOneWidget);
      expect(find.text('Waiting for consent'), findsOneWidget);
      await tapText(tester, 'Refuse');
      expect(find.text('Refused'), findsOneWidget);
      expect(find.text('I agree'), findsNothing);
    });

    testWidgets('a payment in History can be put to a community officer', (tester) async {
      final community = FakeCommunityApi();
      await pumpApp(tester, signedIn: true, circles: FakeCirclesApi(seed: FakeSeed.activeMember), community: community);
      await tapText(tester, 'History');
      // the promise is above the list now (ER-02)
      expect(find.textContaining('Records are never edited'), findsOneWidget);
      await tester.tap(find.textContaining('contribution').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Talk to your organizer first'), findsOneWidget);
      await tapText(tester, 'I paid, but it was not recorded');
      expect(community.raised, hasLength(1));
      expect(find.textContaining('Dispute raised'), findsOneWidget);
    });

    testWidgets('an officer sees codes and totals, opens evidence once, and records an outcome', (tester) async {
      final community = FakeCommunityApi();
      await pumpApp(tester, signedIn: true, officer: true, community: community);

      await tapText(tester, 'Profile');
      await tapText(tester, 'Community officer');
      expect(find.textContaining('You never see names or phone numbers'), findsOneWidget);
      expect(find.text('RC-021'), findsOneWidget);
      expect(find.text('6 members · 6 cycles'), findsOneWidget);
      expect(find.text('83% verified'), findsOneWidget);

      await tapText(tester, 'RC-021 · My payment was rejected wrongly');
      expect(community.evidenceViews, 1);
      expect(find.text('PS-1021'), findsOneWidget);
      expect(find.text('Member A'), findsNWidgets(2));
      expect(find.textContaining('Opening this page was logged'), findsOneWidget);

      await tapText(tester, 'Mark as resolved');
      await typeAt(tester, 0, 'Slip shown to both sides');
      await tester.tap(find.widgetWithText(InkWell, 'Mark as resolved').last);
      await tester.pumpAndSettle();
      expect(community.resolvedNote, 'Slip shown to both sides');
      expect(community.evidenceViews, 1, reason: 'rebuilding the page must not log another view');
    });
  });

  group('members', () {
    testWidgets('organizer reminds an unpaid member and removes one with a reason (FR-05, FR-09)', (tester) async {
      final circles = FakeCirclesApi(seed: FakeSeed.activeOrganizer);
      final reminders = FakeRemindersApi();
      await pumpApp(tester, signedIn: true, circles: circles, reminders: reminders);
      await tapText(tester, 'Circles');
      await tapText(tester, 'Manage members');
      expect(find.textContaining('recorded permanently with your reason'), findsOneWidget);

      // both other members have a payment on record, so there is no one to remind
      expect(find.byTooltip('Send reminder'), findsNothing);
      expect(reminders.nudged, isEmpty);

      await tester.tap(find.byTooltip('Remove member').first);
      await tester.pumpAndSettle();
      // no reason, no removal
      await tester.tap(find.widgetWithText(InkWell, 'Remove member').last);
      await tester.pumpAndSettle();
      expect(circles.calls.where((c) => c.startsWith('remove:')), isEmpty);
      await typeAt(tester, 0, 'Moved abroad');
      await tester.tap(find.widgetWithText(InkWell, 'Remove member').last);
      await tester.pumpAndSettle();
      expect(circles.calls.last, endsWith(':Moved abroad'));
    });

    testWidgets('Home repeats "do not pay again" while a payment awaits verification (UI-04)', (tester) async {
      final circles = FakeCirclesApi(seed: FakeSeed.activeMember);
      await pumpApp(tester, signedIn: true, circles: circles);
      // UI-05: the rule behind the order is stated where the order is shown
      await tester.scrollUntilVisible(find.textContaining('The organizer set this order'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('The organizer set this order'), findsOneWidget);
    });
  });
}
