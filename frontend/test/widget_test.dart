import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pay_and_save/main.dart';

void main() {
  testWidgets('Welcome screen shows the wordmark and Get started button', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PayAndSaveApp()));
    await tester.pumpAndSettle();

    expect(find.text('PAY&SAVE'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('Get started navigates to the Member home screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PayAndSaveApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Friends Seettu'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
