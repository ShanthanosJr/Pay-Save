import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Search field + filter button.
class PsSearchField extends StatelessWidget {
  const PsSearchField({super.key, required this.hintText, this.filterLabel = 'Filter', this.onFilterTap});

  final String hintText;
  final String filterLabel;
  final VoidCallback? onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: const Icon(Icons.search, color: AppColors.inkMuted),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s),
        Semantics(
          button: true,
          label: filterLabel,
          child: Material(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(AppRadii.field),
            child: InkWell(
              onTap: onFilterTap,
              borderRadius: BorderRadius.circular(AppRadii.field),
              child: const SizedBox(
                width: 54,
                height: 54,
                child: Icon(Icons.tune, color: AppColors.onDark),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
