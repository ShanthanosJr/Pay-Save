import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'ps_button.dart';

/// Forest header for pushed sub-pages: back, centred-left title, optional action.
class PsBackHeader extends StatelessWidget {
  const PsBackHeader({super.key, required this.title, required this.backLabel, this.trailing, this.leading});

  final String title;
  final String backLabel;
  final Widget? trailing;

  /// Shown between the back button and the title (e.g. a small avatar).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PsGlassIconButton(
          icon: Icons.arrow_back_rounded,
          label: backLabel,
          onTap: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        const SizedBox(width: AppSpace.m),
        if (leading != null) ...[leading!, const SizedBox(width: AppSpace.s)],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.section.copyWith(color: AppColors.onForest),
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: AppSpace.m), trailing!],
      ],
    );
  }
}
