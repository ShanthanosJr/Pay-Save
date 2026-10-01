import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';
import 'circle_models.dart';

const walletProviders = ['eZ Cash', 'mCash', 'Genie', 'FriMi'];

String methodLabel(AppLocalizations l10n, PaymentMethod m) => switch (m) {
      PaymentMethod.cash => l10n.methodCash,
      PaymentMethod.bankTransfer => l10n.methodBank,
      PaymentMethod.lankaqr => l10n.methodLankaqr,
      PaymentMethod.mobileWallet => l10n.methodWallet,
    };

IconData methodIcon(PaymentMethod m) => switch (m) {
      PaymentMethod.cash => Icons.payments_rounded,
      PaymentMethod.bankTransfer => Icons.account_balance_rounded,
      PaymentMethod.lankaqr => Icons.qr_code_2_rounded,
      PaymentMethod.mobileWallet => Icons.phone_iphone_rounded,
    };

String intervalLabel(AppLocalizations l10n, CircleInterval i) => switch (i) {
      CircleInterval.weekly => l10n.intervalWeekly,
      CircleInterval.fortnightly => l10n.intervalFortnightly,
      CircleInterval.monthly => l10n.intervalMonthly,
    };

String turnRuleLabel(AppLocalizations l10n, TurnRule r) => switch (r) {
      TurnRule.fixed => l10n.turnRuleFixed,
      TurnRule.lottery => l10n.turnRuleLottery,
      TurnRule.needBased => l10n.turnRuleNeed,
    };

String shortDate(AppLocalizations l10n, DateTime d) => DateFormat.MMMd(l10n.localeName).format(d);

String longDate(AppLocalizations l10n, DateTime d) => DateFormat.yMMMd(l10n.localeName).format(d);

String dateTime(AppLocalizations l10n, DateTime d) =>
    '${DateFormat.yMMMd(l10n.localeName).format(d)} · ${DateFormat.jm(l10n.localeName).format(d)}';

/// Whole days from today to [due] (negative once overdue).
int daysUntil(DateTime due, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  return DateTime(due.year, due.month, due.day).difference(today).inDays;
}
