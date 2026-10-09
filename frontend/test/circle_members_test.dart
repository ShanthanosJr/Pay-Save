import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_circles.dart';
import 'support/fakes.dart';
import 'support/pump.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> tapButton(WidgetTester tester, String label) async {
  final f = find.widgetWithText(InkWell, label).last;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Map<String, dynamic> invitationJson() => {
  'id': 'inv1',
  'message': 'Starting in January — join us!',
  'invitedAt': '2026-10-01T09:00:00.000Z',
  'organizer': {'id': 'u-org', 'fullName': 'Kamala Silva', 'username': 'kamala', 'avatarUrl': null},
  'circle': {
    'id': 'c7',
    'name': 'Temple Seettu',
    'contributionMinor': 500000,
    'interval': 'monthly',
    'turnRule': 'fixed',
    'plannedCycles': 5,
    'collectionMode': 'via_organizer',
    'firstDueDate': '2027-01-10',
    'memberCount': 2,
    'seatsLeft': 3,
    'payout': {'count': 5, 'unitMinor': 500000, 'totalMinor': 2500000, 'entryIds': <String>[]},
    'palsInside': ['Ruwan Perera'],
  },
};

void main() {
  group('accepting an invitation', () {
    testWidgets('banner → terms, pot arithmetic, pals inside; default method preselected; accept joins', (tester) async {
      final circles = FakeCirclesApi()..invitations.add(invitationJson());
      await pumpApp(
        tester,
        signedIn: true,
        circles: circles,
        payouts: FakePayoutsApi(initial: [bocMethod]),
      );

      expect(find.text('Kamala Silva invited you to Temple Seettu'), findsOneWidget);
      await tapText(tester, 'Kamala Silva invited you to Temple Seettu');

      expect(find.text('Temple Seettu'), findsOneWidget);
      expect(find.text('“Starting in January — join us!”'), findsOneWidget);
      expect(find.text('5 × LKR 5,000 = LKR 25,000 when it\'s your turn'), findsOneWidget);
      expect(find.text('Ruwan Perera'), findsOneWidget);
      expect(find.text('Organizer collects'), findsOneWidget);
      expect(find.text('2 of 5 members so far'), findsOneWidget);
      // The default method is ticked already.
      expect(find.bySemanticsLabel(RegExp('Bank of Ceylon')), findsOneWidget);

      await tapButton(tester, 'Accept and join');
      expect(circles.calls.last, 'accept:inv1:pm-boc:pm-boc');
      expect(find.text('You joined Temple Seettu'), findsOneWidget);
      expect(circles.invitations, isEmpty);
    });

    testWidgets('with no methods it asks for one, and a new one can be added inline', (tester) async {
      final circles = FakeCirclesApi()..invitations.add(invitationJson());
      final payouts = FakePayoutsApi();
      await pumpApp(tester, signedIn: true, circles: circles, payouts: payouts);
      await tapText(tester, 'Kamala Silva invited you to Temple Seettu');

      await tapButton(tester, 'Accept and join');
      expect(find.text('Choose at least one way to be paid.'), findsOneWidget);
      expect(circles.calls.where((c) => c.startsWith('accept')), isEmpty);

      await tapButton(tester, 'Add a new method');
      await tapText(tester, 'Cash in person');
      await tester.enterText(find.byType(TextFormField), 'After the Sunday pooja');
      await tapButton(tester, 'Save payment method');
      expect(payouts.added.single.note, 'After the Sunday pooja');

      await tapButton(tester, 'Accept and join');
      expect(circles.calls.last, 'accept:inv1:pm-new-1:pm-new-1');
    });

    testWidgets('decline asks first', (tester) async {
      final circles = FakeCirclesApi()..invitations.add(invitationJson());
      await pumpApp(tester, signedIn: true, circles: circles, payouts: FakePayoutsApi(initial: [bocMethod]));
      await tapText(tester, 'Kamala Silva invited you to Temple Seettu');
      await tapButton(tester, 'Decline');
      expect(find.text('Decline this invitation?'), findsOneWidget);
      await tapButton(tester, 'Decline');
      expect(circles.calls.last, 'decline:inv1');
      expect(find.text('Invitation declined'), findsOneWidget);
    });
  });

  group('payment details', () {
    testWidgets('bank account needs the number twice; digits are cleaned', (tester) async {
      final payouts = FakePayoutsApi();
      await pumpApp(tester, signedIn: true, payouts: payouts);
      await tapText(tester, 'Profile');
      await tapText(tester, 'How you get paid');
      expect(find.text('No payment details yet'), findsOneWidget);

      await tapButton(tester, 'Add a payment method');
      await tapText(tester, 'Bank transfer');
      final fields = find.byType(TextFormField);
      // branch, holder (prefilled), number, confirm
      expect(find.text('Nadeeshi Perera'), findsOneWidget);
      await tester.enterText(fields.at(2), '0071 2345 6789');
      await tester.enterText(fields.at(3), '0071 2345 6788');
      await tapButton(tester, 'Save payment method');
      expect(find.text('The account numbers don\'t match'), findsOneWidget);
      expect(payouts.added, isEmpty);

      await tester.enterText(fields.at(3), '007123456789');
      await tapButton(tester, 'Save payment method');
      expect(payouts.added.single.accountNumber, '007123456789');
      expect(payouts.added.single.bankName, 'Bank of Ceylon');
      expect(find.text('Bank of Ceylon · ••••6789'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
    });
  });

  group('inviting pals', () {
    testWidgets('only pals are listed, members and invited are marked, seats cap the selection', (tester) async {
      final circles = FakeCirclesApi(seed: FakeSeed.draftFixedOrganizer)
        ..seatsLeft = 1
        ..invitable.addAll([
          {'id': 'p1', 'fullName': 'Amaya Perera', 'username': 'amaya', 'avatarUrl': null, 'state': 'available'},
          {'id': 'p2', 'fullName': 'Bimal Fernando', 'username': null, 'avatarUrl': null, 'state': 'available'},
          {'id': 'p3', 'fullName': 'Chathuri Silva', 'username': null, 'avatarUrl': null, 'state': 'invited'},
          {'id': 'u-kamala', 'fullName': 'Kamala Silva', 'username': null, 'avatarUrl': null, 'state': 'member'},
        ]);
      await pumpApp(tester, signedIn: true, circles: circles);
      await tapText(tester, 'Circles');
      expect(find.text('Getting ready to start'), findsNothing); // fake circle can already start
      await tapButton(tester, 'Invite pals · 1 seat left');

      expect(find.text('Invited'), findsOneWidget);
      expect(find.text('In circle'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Select Amaya Perera'));
      await tester.pumpAndSettle();
      expect(find.text('No seats left'), findsOneWidget);

      // Bimal can't be picked any more: the seat is taken.
      await tester.tap(find.bySemanticsLabel('Select Bimal Fernando'));
      await tester.pumpAndSettle();
      expect(find.text('Send 1 invitation'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'See you at the temple');
      await tapButton(tester, 'Send 1 invitation');
      expect(circles.calls.last, 'invite:c2:p1:See you at the temple');
      expect(find.text('Invitations sent'), findsOneWidget);
    });
  });

  group('pay to', () {
    Map<String, dynamic> payTo({bool youReceive = false}) => {
      'cycleNumber': 1,
      'dueDate': '2026-10-30',
      'collectionMode': 'direct_to_recipient',
      'youReceive': youReceive,
      'payee': {'id': 'u-kamala', 'fullName': 'Kamala Silva', 'username': null, 'avatarUrl': null},
      'amount': {'count': 1, 'unitMinor': 500000, 'totalMinor': 500000, 'entryIds': <String>[]},
      'reference': 'RC-101 C1 Nadeeshi',
      'methods': youReceive
          ? <Object>[]
          : [
              {
                'id': 'pm-boc',
                'kind': 'bank_transfer',
                'summary': 'Bank of Ceylon · ••••6789',
                'isDefault': true,
                'preferred': true,
                'details': {
                  'kind': 'bank_transfer',
                  'bankName': 'Bank of Ceylon',
                  'branch': 'Kandy',
                  'accountName': 'Kamala Silva',
                  'accountNumber': '007123456789',
                },
              },
            ],
    };

    testWidgets('record sheet shows who to pay, grouped number, copy buttons, matching method', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final circles = FakeCirclesApi(seed: FakeSeed.activeMember)..payToJson = payTo();
      await pumpApp(tester, signedIn: true, circles: circles);
      await tapButton(tester, 'Pay now');

      expect(find.text('Pay to'), findsOneWidget);
      expect(find.text('0071 2345 6789'), findsOneWidget);
      expect(find.text('RC-101 C1 Nadeeshi'), findsOneWidget);

      await tester.tap(find.byTooltip('Copy Account number'));
      await tester.pumpAndSettle();
      expect(copied.last, '007123456789'); // digits only, not the spaced display
      await tester.ensureVisible(find.byTooltip('Copy Note to add to your transfer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Copy Note to add to your transfer'));
      await tester.pumpAndSettle();
      expect(copied.last, 'RC-101 C1 Nadeeshi');

      // Bank transfer is preselected because that is how Kamala gets paid.
      expect(
        find.descendant(
          of: find.ancestor(of: find.text('Bank transfer').last, matching: find.byType(Semantics)).first,
          matching: find.byIcon(Icons.radio_button_checked_rounded),
        ),
        findsWidgets,
      );
    });

    testWidgets('the recipient is told no payment is needed', (tester) async {
      final circles = FakeCirclesApi(seed: FakeSeed.activeMember)..payToJson = payTo(youReceive: true);
      await pumpApp(tester, signedIn: true, circles: circles);
      await tapButton(tester, 'Pay now');
      expect(find.text('This cycle\'s pot comes to you'), findsOneWidget);
      expect(find.byTooltip('Copy Account number'), findsNothing);
    });
  });
}
