import 'package:intl/intl.dart';

final _grouped = NumberFormat('#,##0', 'en');

/// Formats minor units (LKR 5,000.00 = 500000) without floating point.
String formatMinor(int minor) {
  final rupees = minor ~/ 100;
  final cents = (minor % 100).abs();
  final whole = _grouped.format(rupees);
  return cents == 0 ? whole : '$whole.${cents.toString().padLeft(2, '0')}';
}

String formatLkr(int minor) => 'LKR ${formatMinor(minor)}';
