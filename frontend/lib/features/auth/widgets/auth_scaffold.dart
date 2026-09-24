import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'accent_title.dart';

/// Shared frame for login and the registration steps.
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
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.xxl),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - AppSpace.s - AppSpace.xxl),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: AppSpace.minTouch,
                        child: Row(children: [
                          if (onBack != null)
                            Semantics(
                              button: true,
                              label: MaterialLocalizations.of(context).backButtonTooltip,
                              child: InkWell(
                                onTap: onBack,
                                borderRadius: BorderRadius.circular(AppRadii.chip),
                                child: const SizedBox(
                                  width: AppSpace.minTouch,
                                  height: AppSpace.minTouch,
                                  child: Icon(Icons.arrow_back, color: AppColors.ink),
                                ),
                              ),
                            ),
                          const Spacer(),
                          if (stepLabel != null) Text(stepLabel!, style: AppText.caption),
                        ]),
                      ),
                      if (step != null && totalSteps != null) ...[
                        const SizedBox(height: AppSpace.s),
                        Row(
                          children: List.generate(totalSteps!, (i) {
                            return Expanded(
                              child: Container(
                                height: 4,
                                margin: EdgeInsets.only(right: i == totalSteps! - 1 ? 0 : 6),
                                decoration: BoxDecoration(
                                  color: i < step! ? AppColors.ink : AppColors.hairline,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                      const SizedBox(height: AppSpace.xxl),
                      AccentTitle(plain: titlePlain, accent: titleAccent),
                      const SizedBox(height: AppSpace.m),
                      Text(subtitle, style: AppText.body),
                      const SizedBox(height: AppSpace.xxl),
                      child,
                      if (footer != null) ...[
                        const SizedBox(height: AppSpace.xxl),
                        Center(child: footer!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
