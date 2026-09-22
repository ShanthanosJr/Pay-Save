import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Search field + filter button, per design-system §4.2 header row.
class PsSearchField extends StatelessWidget {
  const PsSearchField({super.key, required this.hintText, this.onFilterTap});

  final String hintText;
  final VoidCallback? onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s),
        Semantics(
          button: true,
          label: 'Filter',
          child: InkWell(
            onTap: onFilterTap,
            borderRadius: BorderRadius.circular(AppRadii.search),
            child: Container(
              width: AppSpace.minTouch,
              height: AppSpace.minTouch,
              decoration: BoxDecoration(
                color: AppColors.searchFill,
                borderRadius: BorderRadius.circular(AppRadii.search),
              ),
              child: const Icon(Icons.tune, color: AppColors.searchText),
            ),
          ),
        ),
      ],
    );
  }
}
