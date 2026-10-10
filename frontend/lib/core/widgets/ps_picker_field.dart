import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'ps_sheet.dart';

/// A field that is chosen, not typed: looks like [PsTextField], opens a list
/// to pick from. The choice is written to [controller] as [valueText], so
/// form validation and submit code read it like any other field.
class PsPickerField<T> extends StatelessWidget {
  const PsPickerField({
    super.key,
    required this.label,
    required this.controller,
    required this.options,
    required this.optionLabel,
    required this.sheetTitle,
    this.valueText,
    this.hint,
    this.helper,
    this.validator,
    this.onPicked,
  });

  final String label;
  final TextEditingController controller;
  final List<T> options;

  /// What a row in the list says, e.g. "29 years".
  final String Function(T option) optionLabel;

  /// What is stored in [controller]; defaults to `option.toString()`.
  final String Function(T option)? valueText;
  final String sheetTitle;
  final String? hint;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final ValueChanged<T>? onPicked;

  String _stored(T o) => valueText?.call(o) ?? '$o';

  Future<void> _open(BuildContext context) async {
    final current = options.indexWhere((o) => _stored(o) == controller.text);
    const rowHeight = 56.0;
    final scroll = ScrollController(
      initialScrollOffset: current <= 2 ? 0 : (current - 2) * rowHeight,
    );
    final picked = await showPsSheet<T>(
      context: context,
      title: sheetTitle,
      builder: (ctx) => SizedBox(
        height: (options.length * rowHeight).clamp(rowHeight, 336.0),
        child: Material(
          type: MaterialType.transparency,
          child: ListView.builder(
            controller: scroll,
            itemExtent: rowHeight,
            itemCount: options.length,
            itemBuilder: (ctx, i) {
              final selected = i == current;
              return ListTile(
                selected: selected,
                selectedTileColor: AppColors.mintSoft,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.small)),
                title: Text(
                  optionLabel(options[i]),
                  style: AppText.bodyStrong.copyWith(color: AppColors.ink),
                ),
                trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.forest700) : null,
                onTap: () => Navigator.of(ctx).pop(options[i]),
              );
            },
          ),
        ),
      ),
    );
    scroll.dispose();
    if (picked == null) return;
    controller.text = _stored(picked);
    onPicked?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(label, style: AppText.label.copyWith(color: AppColors.inkMuted)),
        ),
        const SizedBox(height: AppSpace.s),
        Semantics(
          button: true,
          child: TextFormField(
            controller: controller,
            readOnly: true,
            showCursor: false,
            enableInteractiveSelection: false,
            validator: validator,
            style: AppText.bodyStrong,
            onTap: () => _open(context),
            decoration: InputDecoration(
              hintText: hint,
              suffixIcon: const Icon(Icons.expand_more_rounded, color: AppColors.inkMuted),
            ),
          ),
        ),
        // its own line, so it stays visible next to a validation message
        if (helper != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(helper!, style: AppText.caption),
          ),
      ],
    );
  }
}
