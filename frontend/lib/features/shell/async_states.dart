import 'package:flutter/material.dart';

import '../../core/api/error_messages.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_button.dart';
import '../../l10n/gen/app_localizations.dart';

class SheetLoading extends StatelessWidget {
  const SheetLoading({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
}

class SheetError extends StatelessWidget {
  const SheetError({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(children: [
        const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.inkSubtle),
        const SizedBox(height: AppSpace.m),
        Text(messageFor(l10n, error), textAlign: TextAlign.center, style: AppText.body),
        const SizedBox(height: AppSpace.l),
        PsButton(label: l10n.retry, onPressed: onRetry, expand: false, variant: PsButtonVariant.secondary),
      ]),
    );
  }
}

/// Large mint illustration-style empty state.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.actions = const []});

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: Container(
            width: 112,
            height: 112,
            decoration: const BoxDecoration(color: AppColors.mintSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 52, color: AppColors.forest600),
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        Text(title, style: AppText.section, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.s),
        Text(body, style: AppText.body, textAlign: TextAlign.center),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: AppSpace.xxl),
          for (final a in actions) Padding(padding: const EdgeInsets.only(bottom: AppSpace.m), child: a),
        ],
      ]),
    );
  }
}
