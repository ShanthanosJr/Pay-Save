import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Rounded white search field with a clear button. 52dp tall.
class PsSearchField extends StatelessWidget {
  const PsSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.clearLabel,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final String clearLabel;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: AppText.bodyStrong,
        cursorColor: AppColors.forest600,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.inkMuted),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: clearLabel,
                  constraints: const BoxConstraints(minWidth: AppSpace.minTouch, minHeight: AppSpace.minTouch),
                  icon: const Icon(Icons.close_rounded, color: AppColors.inkMuted),
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                  },
                ),
        ),
      ),
    );
  }
}
