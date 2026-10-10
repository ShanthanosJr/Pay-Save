import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pay_and_save/core/providers/prefs_store.dart';

import 'support/pump.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).first;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Settings: text size, language and privacy choices are remembered on the phone', (tester) async {
    final prefs = MemoryPrefsStore();
    await pumpApp(tester, signedIn: true, prefs: prefs);
    await tapText(tester, 'Profile');
    await tapText(tester, 'All settings');
    expect(find.text('Display'), findsOneWidget);

    await tapText(tester, 'Maximised');
    expect(prefs.values['text_size'], 'maximised');

    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(prefs.values['hide_chat_previews'], 'true');

    // the Profile page underneath has the same control; use the one on top
    await tester.ensureVisible(find.text('සිංහල').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('සිංහල').last);
    await tester.pumpAndSettle();
    expect(prefs.values['language'], 'si');
    expect(find.text('සැකසුම්'), findsWidgets);
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    await tapText(tester, 'Your data');
    expect(find.textContaining('never holds or moves your money'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

  });

  testWidgets('a saved language and text size are applied when the app opens', (tester) async {
    final prefs = MemoryPrefsStore()
      ..values['language'] = 'ta'
      ..values['text_size'] = 'enhanced';
    await pumpApp(tester, prefs: prefs);
    expect(find.text('உள்நுழை'), findsOneWidget);
  });
}
