import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pay_and_save/core/auth/auth_controller.dart';
import 'package:pay_and_save/core/circles/circles_providers.dart';
import 'package:pay_and_save/core/social/social_providers.dart';
import 'package:pay_and_save/features/profile/profile_photo.dart';
import 'package:pay_and_save/main.dart';

import 'fake_circles.dart';
import 'fakes.dart';

/// Boots the whole app on a phone-sized screen against in-memory fakes.
Future<(WidgetTester, FakeAuthApi, MemoryTokenStore)> pumpApp(
  WidgetTester tester, {
  bool signedIn = false,
  FakeSocialApi? social,
  FakeCirclesApi? circles,
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
      socialApiProvider.overrideWithValue(social ?? FakeSocialApi()),
      circlesApiProvider.overrideWithValue(circles ?? FakeCirclesApi()),
      imagePickerProvider.overrideWithValue(FakeImagePicker()),
    ],
    child: const PayAndSaveApp(),
  ));
  await tester.pumpAndSettle();
  return (tester, api, store);
}
