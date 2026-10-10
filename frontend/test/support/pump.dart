import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pay_and_save/core/auth/auth_controller.dart';
import 'package:pay_and_save/core/circles/circles_providers.dart';
import 'package:pay_and_save/core/payouts/payouts_api.dart';
import 'package:pay_and_save/core/providers/prefs_store.dart';
import 'package:pay_and_save/core/social/social_providers.dart';
import 'package:pay_and_save/features/profile/profile_photo.dart';
import 'package:pay_and_save/main.dart';

import 'package:pay_and_save/core/community/community.dart';
import 'package:pay_and_save/core/notifications/notifications.dart';
import 'package:pay_and_save/core/outbox/outbox.dart';
import 'package:pay_and_save/core/reminders/reminders.dart';
import 'package:pay_and_save/core/statements/file_sharer.dart';
import 'package:pay_and_save/core/statements/statements.dart';

import 'fake_circles.dart';
import 'fake_extras.dart';
import 'fakes.dart';

/// Boots the whole app on a phone-sized screen against in-memory fakes.
Future<(WidgetTester, FakeAuthApi, MemoryTokenStore)> pumpApp(
  WidgetTester tester, {
  bool signedIn = false,
  FakeSocialApi? social,
  FakeCirclesApi? circles,
  FakePayoutsApi? payouts,
  FakeNotificationsApi? notifications,
  FakeRemindersApi? reminders,
  FakeStatementsApi? statements,
  FakeCommunityApi? community,
  List<String>? sharedFiles,
  bool officer = false,
  OutboxStore? outbox,
  MemoryPrefsStore? prefs,
}) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final api = FakeAuthApi()..officer = officer;
  final store = MemoryTokenStore();
  if (signedIn) store.tokens = testTokens;

  await tester.pumpWidget(ProviderScope(
    overrides: [
      authApiProvider.overrideWithValue(api),
      tokenStoreProvider.overrideWithValue(store),
      socialApiProvider.overrideWithValue(social ?? FakeSocialApi()),
      circlesApiProvider.overrideWithValue(circles ?? FakeCirclesApi()),
      payoutsApiProvider.overrideWithValue(payouts ?? FakePayoutsApi()),
      imagePickerProvider.overrideWithValue(FakeImagePicker()),
      prefsStoreProvider.overrideWithValue(prefs ?? MemoryPrefsStore()),
      outboxStoreProvider.overrideWithValue(outbox ?? MemoryOutboxStore()),
      notificationsApiProvider.overrideWithValue(notifications ?? FakeNotificationsApi()),
      remindersApiProvider.overrideWithValue(reminders ?? FakeRemindersApi()),
      statementsApiProvider.overrideWithValue(statements ?? FakeStatementsApi()),
      communityApiProvider.overrideWithValue(community ?? FakeCommunityApi()),
      fileSharerProvider.overrideWithValue((bytes, {required name, required mimeType}) async => sharedFiles?.add(name)),
    ],
    child: const PayAndSaveApp(),
  ));
  await tester.pumpAndSettle();
  return (tester, api, store);
}
