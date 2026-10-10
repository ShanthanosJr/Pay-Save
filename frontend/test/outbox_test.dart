import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pay_and_save/core/circles/circle_models.dart';
import 'package:pay_and_save/core/outbox/outbox.dart';
import 'package:pay_and_save/core/outbox/outbox_db.dart';

import 'support/fake_circles.dart';
import 'support/pump.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).first;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

PendingContribution pending(String id, {String user = 'u1', String? failure}) => PendingContribution(
      clientEntryId: id,
      userId: user,
      circleId: 'c1',
      cycleNumber: 2,
      method: PaymentMethod.mobileWallet,
      deviceCreatedAt: DateTime.utc(2026, 10, 10, 8, 30),
      provider: 'Genie',
      receiptReference: 'TX-1',
      failure: failure,
    );

void main() {
  test('the SQLite outbox keeps a payment across restarts, per account', () async {
    final db = OutboxDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftOutboxStore(db);

    await store.put(pending('a'));
    await store.put(pending('b', user: 'someone-else'));
    // saving the same id again replaces it; it never becomes a second payment
    await store.put(pending('a', failure: 'CYCLE_NOT_OPEN'));

    final mine = await DriftOutboxStore(db).all('u1');
    expect(mine, hasLength(1));
    expect(mine.single.clientEntryId, 'a');
    expect(mine.single.method, PaymentMethod.mobileWallet);
    expect(mine.single.provider, 'Genie');
    expect(mine.single.deviceCreatedAt.toUtc(), DateTime.utc(2026, 10, 10, 8, 30));
    expect(mine.single.failure, 'CYCLE_NOT_OPEN');

    await store.remove('a');
    expect(await store.all('u1'), isEmpty);
    expect(await store.all('someone-else'), hasLength(1));
  });

  testWidgets('no signal: saved on this phone, Pay now gone, then sent once with the same id (NFR-03, U-01)',
      (tester) async {
    final circles = FakeCirclesApi(seed: FakeSeed.activeMember)..offline = true;
    final store = MemoryOutboxStore();
    await pumpApp(tester, signedIn: true, circles: circles, outbox: store);

    await tapText(tester, 'Pay now');
    await tapText(tester, 'Record payment');
    expect(find.text('Saved on this phone'), findsWidgets);
    expect(find.textContaining('Do not pay again'), findsWidgets);
    expect(find.textContaining('PS-'), findsNothing, reason: 'no server reference exists yet');
    expect(await store.all('u1'), hasLength(1));
    await tapText(tester, 'Done');

    // Home tells the truth: on the phone, not confirmed, and no way to pay twice
    expect(find.text('Pay now'), findsNothing);
    expect(find.text('Saved on this phone'), findsWidgets);
    expect(circles.calls.where((c) => c.startsWith('record:')), isEmpty);

    // still offline: trying again changes nothing
    await tapText(tester, 'Send now');
    expect(await store.all('u1'), hasLength(1));

    circles.offline = false;
    await tapText(tester, 'Send now');
    expect(circles.calls.where((c) => c.startsWith('record:')), hasLength(1));
    expect(circles.attempts.toSet(), hasLength(1), reason: 'every retry reused the device-generated id');
    expect(await store.all('u1'), isEmpty);
    expect(find.text('Saved on this phone'), findsNothing);
    expect(find.text('Awaiting verification'), findsWidgets);
    expect(find.text('Pay now'), findsNothing);
  });

  testWidgets('a payment the server refuses is shown as NOT recorded and can be removed', (tester) async {
    final circles = FakeCirclesApi(seed: FakeSeed.activeMember);
    final store = MemoryOutboxStore();
    await store.put(PendingContribution(
      clientEntryId: 'stale',
      userId: 'u1',
      circleId: 'c1',
      cycleNumber: 1,
      method: PaymentMethod.cash,
      deviceCreatedAt: DateTime(2026, 10, 1),
      failure: 'CYCLE_NOT_OPEN',
    ));
    await pumpApp(tester, signedIn: true, circles: circles, outbox: store);
    expect(find.textContaining('This payment was NOT recorded'), findsOneWidget);
    await tapText(tester, 'Remove from this phone');
    expect(await store.all('u1'), isEmpty);
    expect(find.text('Pay now'), findsOneWidget);
  });
}
