import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pay_and_save/core/validation/input_formatters.dart';
import 'package:pay_and_save/core/widgets/ps_password_strength.dart';

/// Types [text] at the end of an empty field.
String typed(TextInputFormatter f, String text) => f
    .formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)),
    )
    .text;

void main() {
  test('phone numbers are grouped the way they are read out', () {
    final f = PhoneInputFormatter();
    expect(typed(f, '0771234567'), '077 123 4567');
    expect(typed(f, '077-123 45'), '077 123 45');
    expect(typed(f, '07712345678999'), '077 123 4567', reason: 'extra digits are dropped');
    expect(typed(f, '+94771234567'), '+94 77 123 4567');
    expect(typed(f, '94771234567'), '+94 77 123 4567');
    expect(typed(f, ''), '');
  });

  test('the caret stays after the digit just typed', () {
    final out = PhoneInputFormatter().formatEditUpdate(
      const TextEditingValue(text: '077 1'),
      const TextEditingValue(text: '077 12', selection: TextSelection.collapsed(offset: 6)),
    );
    expect(out.text, '077 12');
    expect(out.selection.baseOffset, 6);
    // inserting in the middle keeps the caret with the inserted digit
    final mid = PhoneInputFormatter().formatEditUpdate(
      const TextEditingValue(text: '077 123'),
      const TextEditingValue(text: '0977 123', selection: TextSelection.collapsed(offset: 2)),
    );
    expect(mid.text, '097 712 3');
    expect(mid.selection.baseOffset, 2);
  });

  test('NIC: upper-cases the letter, keeps both formats, drops anything else', () {
    final f = NicInputFormatter();
    expect(typed(f, '901234567v'), '901234567V');
    expect(typed(f, '901234567x99'), '901234567X');
    expect(typed(f, '2000 1234-5678'), '200012345678');
    expect(typed(f, '2000123456789'), '200012345678');
    expect(typed(f, '90v1234'), '901234', reason: 'a letter is only valid as the 10th character');
  });

  test('rupees get thousands separators and parse back exactly', () {
    final f = RupeeInputFormatter();
    expect(typed(f, '5000'), '5,000');
    expect(typed(f, '0025000'), '25,000');
    expect(typed(f, '1000000'), '1,000,000');
    expect(typed(f, '12345678'), '1,234,567');
    expect(typed(f, 'abc'), '');
    expect(RupeeInputFormatter.parse('1,250,000'), 1250000);
    expect(RupeeInputFormatter.parse(''), 0);
  });

  test('age is worked out from either NIC format', () {
    final today = DateTime(2026, 10, 10);
    expect(ageFromNic('200012345678', today: today), 26); // born on day 123 of 2000
    expect(ageFromNic('901234567V', today: today), 36);
    expect(ageFromNic('906234567v', today: today), 36, reason: 'women: day + 500');
    // birthday later in the year has not happened yet
    expect(ageFromNic('200030045678', today: DateTime(2026, 3, 1)), 25);
    expect(ageFromNic('20001234567', today: today), isNull);
    expect(ageFromNic('900004567V', today: today), isNull);
  });

  test('password strength follows the sign-up rule', () {
    expect(PsPasswordStrength.score('abcdefgh'), 0, reason: 'no number');
    expect(PsPasswordStrength.score('abc123'), 0, reason: 'too short');
    expect(PsPasswordStrength.score('abcd1234'), 1);
    expect(PsPasswordStrength.score('Abcd1234efgh'), 2);
  });
}
