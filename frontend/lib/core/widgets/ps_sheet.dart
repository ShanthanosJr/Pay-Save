import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Opens a floating white card sheet with title, subtitle and a close X —
/// the reference's "Add new sensor" / "Actions" panel.
Future<T?> showPsSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + MediaQuery.of(ctx).viewInsets.bottom),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.sheet),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Semantics(header: true, child: Text(title, style: AppText.title)),
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
                      constraints: const BoxConstraints(minWidth: AppSpace.minTouch, minHeight: AppSpace.minTouch),
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded, color: AppColors.ink, size: 26),
                    ),
                  ]),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: Text(subtitle, style: AppText.body),
                    ),
                  const SizedBox(height: AppSpace.xxl),
                  Padding(padding: const EdgeInsets.only(right: 8), child: builder(ctx)),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
