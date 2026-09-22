import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AGENTS.md rule 11: every user-visible string must have a key in all
/// three ARB files. This fails the build the moment `si` or `ta` falls
/// behind `en`, instead of silently showing English (the U-04 bug).
void main() {
  test('app_si.arb and app_ta.arb have every key from app_en.arb, non-empty', () {
    final en = _loadArb('app_en.arb');
    final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();

    for (final locale in ['si', 'ta']) {
      final translated = _loadArb('app_$locale.arb');
      final translatedKeys = translated.keys.where((k) => !k.startsWith('@')).toSet();

      final missing = enKeys.difference(translatedKeys);
      expect(
        missing,
        isEmpty,
        reason: 'app_$locale.arb is missing keys present in app_en.arb: $missing',
      );

      for (final key in enKeys) {
        final value = translated[key];
        expect(
          value,
          isA<String>(),
          reason: 'app_$locale.arb key "$key" must be a string',
        );
        expect(
          (value as String).trim(),
          isNotEmpty,
          reason: 'app_$locale.arb key "$key" must not be empty',
        );
      }
    }
  });
}

Map<String, dynamic> _loadArb(String filename) {
  final file = File('lib/l10n/$filename');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}
