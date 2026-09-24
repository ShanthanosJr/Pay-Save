import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Inline error: icon + words, never colour alone.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.m),
        decoration: BoxDecoration(
          color: const Color(0x1AC0392B),
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.error_outline, size: 20, color: AppColors.statusDue),
          const SizedBox(width: AppSpace.s),
          Expanded(child: Text(message, style: AppText.small.copyWith(color: AppColors.statusDue))),
        ]),
      ),
    );
  }
}
