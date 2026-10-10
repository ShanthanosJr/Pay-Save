import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pay_and_save/core/auth/auth_controller.dart';
import 'package:pay_and_save/core/circles/circles_providers.dart';
import 'package:pay_and_save/core/outbox/outbox.dart';
import 'package:pay_and_save/core/payouts/payouts_api.dart';
import 'package:pay_and_save/core/social/social_providers.dart';
import 'package:pay_and_save/features/circle/join_circle_screen.dart';
import 'package:pay_and_save/main.dart';

import 'support/fake_circles.dart';
import 'support/fakes.dart';

Future<FakeCirclesApi> pumpSignedIn(WidgetTester tester, FakeSeed seed) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final circles = FakeCirclesApi(seed: seed);
  final store = MemoryTokenStore()..tokens = testTokens;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authApiProvider.overrideWithValue(FakeAuthApi()),
      tokenStoreProvider.overrideWithValue(store),
      circlesApiProvider.overrideWithValue(circles),
      socialApiProvider.overrideWithValue(FakeSocialApi()),
      payoutsApiProvider.overrideWithValue(FakePayoutsApi()),
      outboxStoreProvider.overrideWithValue(MemoryOutboxStore()),
    ],
    child: const PayAndSaveApp(),
  ));
  await tester.pumpAndSettle();
  return circles;
}

Future<void> tapText(WidgetTester tester, String text, {bool first = false}) async {
  final f = first ? find.text(text).first : find.text(text);
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

void main() {
  test('join codes are normalised the way people type them', () {
    expect(normalizeJoinCode(' k7p2-qxmh '), 'K7P2QXMH');
    expect(normalizeJoinCode('K7P2 QXMH'), 'K7P2QXMH');
  });

  testWidgets('No circles: Home offers create and join', (tester) async {
    await pumpSignedIn(tester, FakeSeed.none);
    expect(find.text('Start your first circle'), findsOneWidget);
    expect(find.text('Create a circle'), findsOneWidget);
    expect(find.text('Join with a code'), findsOneWidget);
  });

  testWidgets('Create circle in three steps lands on the draft with a join code', (tester) async {
    final api = await pumpSignedIn(tester, FakeSeed.none);
    await tapButton(tester, 'Create a circle');

    await tapButton(tester, 'Continue');
    expect(find.text('This field is required'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Office Seettu');
    await tester.enterText(find.byType(TextFormField).at(1), '5000');
    await tapButton(tester, 'Continue');

    expect(find.text('Step 2 of 3'), findsOneWidget);
    await tapText(tester, 'Weekly');
    await tester.enterText(find.byType(TextFormField).first, '4');
    await tapButton(tester, 'Continue');

    expect(find.text('Step 3 of 3'), findsOneWidget);
    await tapText(tester, 'Lottery');
    expect(find.text('4 members × LKR 5,000 = LKR 20,000 per payout'), findsOneWidget);
    await tapButton(tester, 'Create circle');

    expect(api.calls.single, startsWith('create:Office Seettu:500000:weekly:lottery:4:'));
    expect(find.text('Waiting to start'), findsOneWidget);
    expect(find.text('K7P2 QXMH'), findsOneWidget);
  });

  testWidgets('Join with a code: bad code errors, good code joins', (tester) async {
    final api = await pumpSignedIn(tester, FakeSeed.none);
    await tapButton(tester, 'Join with a code');

    await tester.enterText(find.byType(TextFormField), 'abcd-efgh');
    await tapButton(tester, 'Join circle');
    expect(find.text('No circle matches that code.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'k7p2-qxmh');
    await tapButton(tester, 'Join circle');
    expect(api.calls.last, 'join:K7P2QXMH');
    expect(find.text('Temple Road Seettu'), findsOneWidget);
    expect(find.text('2 of 5 members have joined. Your organizer will start the circle.'), findsOneWidget);
  });

  testWidgets('Member records a wallet payment and gets a dated confirmation', (tester) async {
    final api = await pumpSignedIn(tester, FakeSeed.activeMember);
    expect(find.text('Contribution due'), findsOneWidget);
    expect(find.text('1 verified × LKR 5,000 = LKR 5,000'), findsOneWidget);

    await tapButton(tester, 'Pay now');
    expect(find.text('Record your payment'), findsOneWidget);
    await tapText(tester, 'Mobile wallet');
    await tapText(tester, 'Genie');
    await tester.enterText(find.byType(TextFormField), 'TX-99812');
    await tapButton(tester, 'Record payment');

    expect(api.calls.last, 'record:u-me:mobile_wallet:Genie:TX-99812');
    expect(find.text('PS-1006'), findsOneWidget);
    expect(find.textContaining('Do not pay again'), findsWidgets);
    await tapButton(tester, 'Done');

    // Pay now is gone once a record exists for the cycle (U-01).
    expect(find.text('Pay now'), findsNothing);
    expect(find.text('Awaiting verification'), findsWidgets);
  });

  testWidgets('Organizer verifies from the queue', (tester) async {
    final api = await pumpSignedIn(tester, FakeSeed.activeOrganizer);
    await tapText(tester, 'Payments to verify');
    expect(find.text('Ruwan Perera'), findsOneWidget);

    await tapText(tester, 'Ruwan Perera');
    expect(find.text('BOC-77812'), findsOneWidget);
    await tapButton(tester, 'Verify');

    expect(api.calls.last, startsWith('verify:'));
    expect(find.text('PS-1003 verified'), findsOneWidget);
    expect(find.text('All caught up'), findsOneWidget);
  });

  testWidgets('Organizer rejects with a required reason', (tester) async {
    final api = await pumpSignedIn(tester, FakeSeed.activeOrganizer);
    await tapText(tester, 'Circles');
    await tapText(tester, 'Ruwan Perera', first: true);
    await tapButton(tester, 'Reject');

    expect(find.text('Reject PS-1003?'), findsOneWidget);
    await tapButton(tester, 'Reject');
    expect(find.text('Give a short reason'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'No transfer received');
    await tapButton(tester, 'Reject');
    expect(api.calls.last, contains(':No transfer received'));
    expect(find.text('PS-1003 rejected'), findsOneWidget);
  });

  testWidgets('Close cycle names the unpaid and needs the acknowledgement', (tester) async {
    final api = await pumpSignedIn(tester, FakeSeed.activeOrganizer);
    // Clear the awaiting payment first so only the unpaid rule applies.
    await tapText(tester, 'Payments to verify');
    await tapText(tester, 'Ruwan Perera');
    await tapButton(tester, 'Verify');
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    await tapText(tester, 'Circles');
    await tapButton(tester, 'Close cycle 1');
    expect(find.text('Not paid this cycle'), findsOneWidget);
    await tapButton(tester, 'Close and record payout');
    expect(api.calls.where((c) => c.startsWith('close')), isEmpty);

    await tapText(tester, 'Close with 1 unpaid');
    await tapButton(tester, 'Close and record payout');
    expect(api.calls.last, 'close:1:1');
  });

  testWidgets('Fixed circle: organizer reorders and starts', (tester) async {
    final api = await pumpSignedIn(tester, FakeSeed.draftFixedOrganizer);
    await tapText(tester, 'Circles');
    expect(find.text('Set the turn order'), findsWidgets);

    await tester.ensureVisible(find.byTooltip('Move Nadeeshi Perera down'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Move Nadeeshi Perera down'));
    await tester.pumpAndSettle();
    await tapButton(tester, 'Start circle');
    expect(find.text('Start Office Seettu?'), findsOneWidget);
    await tapButton(tester, 'Start circle');

    expect(api.calls.last, 'start:c2:u-kamala,u-me,u-ruwan');
    expect(find.text('Payout schedule'), findsOneWidget);
  });

  testWidgets('Lottery circle: commit shows the fingerprint, then reveal starts', (tester) async {
    final api = await pumpSignedIn(tester, FakeSeed.draftLotteryOrganizer);
    await tapText(tester, 'Circles');
    await tapButton(tester, 'Draw order');
    expect(api.calls.last, 'commit:c2');
    expect(find.text('Draw fingerprint'), findsOneWidget);

    await tapButton(tester, 'Reveal order and start');
    await tapButton(tester, 'Reveal order and start');
    expect(api.calls.last, 'start:c2:lottery');
    expect(find.text('Draw seed (revealed)'), findsOneWidget);
  });

  testWidgets('Passbook shows the rejected record as corrected, with the reason', (tester) async {
    await pumpSignedIn(tester, FakeSeed.activeMember);
    await tapText(tester, 'History');
    expect(find.text('Corrected'), findsOneWidget);
    expect(find.textContaining('No transfer received'), findsOneWidget);

    await tapText(tester, 'Pending');
    expect(find.text('Nothing waiting'), findsOneWidget);
  });
}
