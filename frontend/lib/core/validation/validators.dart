import '../../l10n/gen/app_localizations.dart';

/// Client-side checks that mirror the server rules. The server stays the
/// authority; these only give instant feedback.
class Validators {
  Validators(this.l10n);

  final AppLocalizations l10n;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static final _username = RegExp(r'^[a-z0-9._]{3,30}$');

  /// Optional; '@' and case are ignored, as on the server.
  String? username(String? v) {
    final t = normalizeUsername(v ?? '');
    return t.isEmpty || _username.hasMatch(t) ? null : l10n.errUsernameFormat;
  }

  static String normalizeUsername(String v) => v.trim().replaceFirst(RegExp('^@'), '').toLowerCase();

  String? required(String? v) => (v == null || v.trim().isEmpty) ? l10n.errRequired : null;

  String? fullName(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return l10n.errRequired;
    return t.length < 2 || !t.contains(RegExp(r'\S')) ? l10n.errNameShort : null;
  }

  String? age(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return l10n.errRequired;
    final n = int.tryParse(t);
    return (n == null || n < 18 || n > 120) ? l10n.errAgeRange : null;
  }

  String? nic(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return l10n.errRequired;
    return isValidNic(t) ? null : l10n.errNicFormat;
  }

  String? phone(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return l10n.errRequired;
    return normalizePhone(t) == null ? l10n.errPhoneFormat : null;
  }

  String? email(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return l10n.errRequired;
    return _email.hasMatch(t) ? null : l10n.errEmailFormat;
  }

  String? newPassword(String? v) {
    final t = v ?? '';
    if (t.isEmpty) return l10n.errRequired;
    final ok = t.length >= 8 && t.length <= 72 && t.contains(RegExp(r'[A-Za-z]')) && t.contains(RegExp(r'\d'));
    return ok ? null : l10n.errPasswordWeak;
  }

  String? Function(String?) confirmPassword(String Function() original) => (v) {
        if (v == null || v.isEmpty) return l10n.errRequired;
        return v == original() ? null : l10n.errPasswordMismatch;
      };

  String? identifier(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return l10n.errIdentifier;
    if (t.contains('@')) return _email.hasMatch(t) ? null : l10n.errEmailFormat;
    return normalizePhone(t) == null ? l10n.errPhoneFormat : null;
  }
}

/// Mirrors the server: the NIC's day-of-year code must be 001–366 (or
/// 501–866, the female offset), and a 12-digit NIC starts with a year ≥ 1900.
bool isValidNic(String input) {
  final nic = input.trim().toUpperCase();
  bool day(int d) => (d >= 1 && d <= 366) || (d >= 501 && d <= 866);
  if (RegExp(r'^\d{9}[VX]$').hasMatch(nic)) return day(int.parse(nic.substring(2, 5)));
  if (RegExp(r'^\d{12}$').hasMatch(nic)) {
    return int.parse(nic.substring(0, 4)) >= 1900 && day(int.parse(nic.substring(4, 7)));
  }
  return false;
}

/// Returns +947XXXXXXXX for 07XXXXXXXX / 947XXXXXXXX / +947XXXXXXXX, else null.
String? normalizePhone(String input) {
  final s = input.replaceAll(RegExp(r'[\s\-()]'), '');
  final m = RegExp(r'^(?:\+94|94|0)(7\d{8})$').firstMatch(s);
  return m == null ? null : '+94${m.group(1)}';
}

/// Login accepts an email or a phone; emails are lower-cased, phones normalised.
String normalizeIdentifier(String input) {
  final t = input.trim();
  if (t.contains('@')) return t.toLowerCase();
  return normalizePhone(t) ?? t;
}
