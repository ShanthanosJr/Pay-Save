import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Rewrites the text and keeps the caret after the same number of
/// "significant" characters, so typing in the middle of a field behaves.
TextEditingValue _reformat(TextEditingValue value, String formatted, bool Function(String ch) significant) {
  final before = value.text.substring(0, value.selection.end.clamp(0, value.text.length));
  final wanted = before.split('').where(significant).length;
  var offset = 0;
  for (var seen = 0; offset < formatted.length && seen < wanted; offset++) {
    if (significant(formatted[offset])) seen++;
  }
  return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: offset));
}

bool _isDigit(String ch) => ch.compareTo('0') >= 0 && ch.compareTo('9') <= 0;

/// Sri Lankan mobile numbers as people read them out: `077 123 4567`, or
/// `+94 77 123 4567` when typed with the country code.
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final plus = newValue.text.trimLeft().startsWith('+');
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final String out;
    if (plus || digits.startsWith('94')) {
      if (digits.length > 11) digits = digits.substring(0, 11);
      out = '+${_groups(digits, const [2, 2, 3, 4])}';
    } else {
      if (digits.length > 10) digits = digits.substring(0, 10);
      out = _groups(digits, const [3, 3, 4]);
    }
    return _reformat(newValue, out, _isDigit);
  }

  static String _groups(String digits, List<int> sizes) {
    final parts = <String>[];
    var i = 0;
    for (final size in sizes) {
      if (i >= digits.length) break;
      final end = (i + size).clamp(0, digits.length);
      parts.add(digits.substring(i, end));
      i = end;
    }
    return parts.join(' ');
  }
}

/// National ID: 12 digits, or 9 digits and a V/X that is typed in any case.
class NicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.toUpperCase().replaceAll(RegExp(r'[^0-9VX]'), '');
    final String t;
    if (raw.indexOf(RegExp(r'[VX]')) == 9) {
      // old format: the letter is always the 10th character and ends it
      t = raw.substring(0, 10);
    } else {
      final digits = raw.replaceAll(RegExp(r'[VX]'), '');
      t = digits.length > 12 ? digits.substring(0, 12) : digits;
    }
    final offset = newValue.selection.end.clamp(0, t.length);
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: offset));
  }
}

/// Whole rupees with thousands separators while typing: `25,000`.
class RupeeInputFormatter extends TextInputFormatter {
  RupeeInputFormatter({this.maxDigits = 7});

  final int maxDigits;
  static final _grouped = NumberFormat('#,##0', 'en');

  /// The number behind what [RupeeInputFormatter] shows.
  static int parse(String text) => int.tryParse(text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);
    final out = digits.isEmpty ? '' : _grouped.format(int.parse(digits));
    return _reformat(newValue, out, _isDigit);
  }
}

/// Emails are stored in lower case; show them that way as they are typed.
class LowerCaseInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toLowerCase().replaceAll(' ', ''));
}

/// Age in whole years from a valid NIC (both formats carry the birth year
/// and the day of the year), or null.
int? ageFromNic(String input, {DateTime? today}) {
  final nic = input.trim().toUpperCase();
  int year;
  int day;
  if (RegExp(r'^\d{9}[VX]$').hasMatch(nic)) {
    year = 1900 + int.parse(nic.substring(0, 2));
    day = int.parse(nic.substring(2, 5));
  } else if (RegExp(r'^\d{12}$').hasMatch(nic)) {
    year = int.parse(nic.substring(0, 4));
    day = int.parse(nic.substring(4, 7));
  } else {
    return null;
  }
  if (day > 500) day -= 500; // women's numbers are offset by 500
  if (day < 1 || day > 366) return null;
  final now = today ?? DateTime.now();
  // the NIC counts every year as a leap year
  final birthday = DateTime(now.year, 1, 1).add(Duration(days: day - 1));
  final age = now.year - year - (now.isBefore(birthday) ? 1 : 0);
  return age < 0 || age > 120 ? null : age;
}
