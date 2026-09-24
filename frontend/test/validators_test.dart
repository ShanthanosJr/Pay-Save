import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pay_and_save/core/validation/validators.dart';
import 'package:pay_and_save/l10n/gen/app_localizations.dart';
import 'package:pay_and_save/l10n/gen/app_localizations_en.dart';

void main() {
  group('normalizePhone', () {
    test('accepts local, 94 and +94 mobile forms', () {
      expect(normalizePhone('0771234567'), '+94771234567');
      expect(normalizePhone('077 123 4567'), '+94771234567');
      expect(normalizePhone('94771234567'), '+94771234567');
      expect(normalizePhone('+94771234567'), '+94771234567');
    });

    test('rejects landlines, short numbers and foreign numbers', () {
      expect(normalizePhone('0112345678'), isNull);
      expect(normalizePhone('077123456'), isNull);
      expect(normalizePhone('+14155550123'), isNull);
      expect(normalizePhone('abc'), isNull);
    });
  });

  test('normalizeIdentifier lower-cases emails and normalises phones', () {
    expect(normalizeIdentifier('  Me@Example.COM '), 'me@example.com');
    expect(normalizeIdentifier('0771234567'), '+94771234567');
  });

  group('Validators', () {
    late Validators v;
    setUp(() => v = Validators(AppLocalizationsEn()));

    test('NIC accepts 9 digits + V/X and 12 digits only', () {
      expect(v.nic('901234567V'), isNull);
      expect(v.nic('901234567x'), isNull);
      expect(v.nic('200012345678'), isNull);
      expect(v.nic('90123456V'), isNotNull);
      expect(v.nic('2000123456789'), isNotNull);
      expect(v.nic(''), isNotNull);
    });

    test('age must be 18-120', () {
      expect(v.age('17'), isNotNull);
      expect(v.age('18'), isNull);
      expect(v.age('120'), isNull);
      expect(v.age('121'), isNotNull);
      expect(v.age('abc'), isNotNull);
    });

    test('password needs 8+ chars with a letter and a digit', () {
      expect(v.newPassword('abcdefgh'), isNotNull);
      expect(v.newPassword('12345678'), isNotNull);
      expect(v.newPassword('abc1234'), isNotNull);
      expect(v.newPassword('abcd1234'), isNull);
    });

    test('email and identifier', () {
      expect(v.email('a@b.co'), isNull);
      expect(v.email('a@b'), isNotNull);
      expect(v.identifier('me@example.com'), isNull);
      expect(v.identifier('0771234567'), isNull);
      expect(v.identifier('12345'), isNotNull);
    });

    test('confirm password must match', () {
      final check = v.confirmPassword(() => 'abcd1234');
      expect(check('abcd1234'), isNull);
      expect(check('other'), isNotNull);
    });
  });

  test('en locale is supported', () {
    expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
  });
}
