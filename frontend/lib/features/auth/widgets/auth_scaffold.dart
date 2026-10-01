import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ps_button.dart';
import '../../../core/widgets/ps_forest_page.dart';
import '../../../core/widgets/ps_logo.dart';
import '../../../core/widgets/ps_section.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Shared frame for login and the registration steps: forest header with
/// back button and logo, light sheet with step bars, title and form.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.titlePlain,
    required this.titleAccent,
    required this.subtitle,
    required this.child,
    this.onBack,
    this.stepLabel,
    this.step,
    this.totalSteps,
    this.footer,
  });

  final String titlePlain;
  final String titleAccent;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;
  final String? stepLabel;
  final int? step;
  final int? totalSteps;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.forest800,
      body: PsForestPage(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
        header: Row(children: [
          if (onBack != null)
            PsGlassIconButton(
              icon: Icons.arrow_back_rounded,
              label: MaterialLocalizations.of(context).backButtonTooltip,
              onTap: onBack!,
            )
          else
            const SizedBox(width: AppSpace.minTouch),
          Expanded(child: Center(child: PsLogo(size: 28, wordmark: l10n.wordmark))),
          SizedBox(
            width: AppSpace.minTouch,
            child: stepLabel == null
                ? null
                : Text(
                    '$step/$totalSteps',
                    textAlign: TextAlign.end,
                    semanticsLabel: stepLabel,
                    style: AppText.label.copyWith(color: AppColors.onForestMuted),
                  ),
          ),
        ]),
        children: [
          if (step != null && totalSteps != null) ...[
            PsStepBars(step: step!, total: totalSteps!),
            const SizedBox(height: AppSpace.m),
            Text(stepLabel ?? '', style: AppText.caption),
            const SizedBox(height: AppSpace.l),
          ],
          Semantics(
            header: true,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$titlePlain ', style: AppText.display),
              TextSpan(text: titleAccent, style: AppText.display.copyWith(color: AppColors.forest600)),
            ])),
          ),
          const SizedBox(height: AppSpace.m),
          Text(subtitle, style: AppText.body),
          const SizedBox(height: AppSpace.xxl + 4),
          child,
          if (footer != null) ...[
            const SizedBox(height: AppSpace.xxl),
            Center(child: footer!),
          ],
        ],
      ),
    );
  }
}
