import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Live feedback under a new-password field: each rule ticks as it is met,
/// with a strength word. Words and icons, never colour alone.
class PsPasswordStrength extends StatelessWidget {
  const PsPasswordStrength({super.key, required this.controller});

  final TextEditingController controller;

  /// 0 = rules not met, 1 = acceptable, 2 = strong.
  static int score(String p) {
    final ok = p.length >= 8 && p.contains(RegExp(r'[A-Za-z]')) && p.contains(RegExp(r'\d'));
    if (!ok) return 0;
    final variety = [RegExp(r'[a-z]'), RegExp(r'[A-Z]'), RegExp(r'\d'), RegExp(r'[^A-Za-z0-9]')]
        .where((r) => p.contains(r))
        .length;
    return p.length >= 12 && variety >= 3 ? 2 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final p = value.text;
        if (p.isEmpty) return const SizedBox.shrink();
        final s = score(p);
        final (String word, Color color) = switch (s) {
          0 => (l10n.pwStrengthWeak, AppColors.danger),
          1 => (l10n.pwStrengthGood, AppColors.warning),
          _ => (l10n.pwStrengthStrong, AppColors.success),
        };
        Widget rule(bool met, String text) => Row(children: [
              Icon(
                met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: met ? AppColors.success : AppColors.inkSubtle,
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(text, style: AppText.caption)),
            ]);
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Semantics(
            liveRegion: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: i <= s ? color : AppColors.stroke,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                Text(word, style: AppText.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              rule(p.length >= 8, l10n.pwRuleLength),
              rule(p.contains(RegExp(r'[A-Za-z]')), l10n.pwRuleLetter),
              rule(p.contains(RegExp(r'\d')), l10n.pwRuleNumber),
            ]),
          ),
        );
      },
    );
  }
}
