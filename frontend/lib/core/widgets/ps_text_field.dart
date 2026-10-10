import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Labelled form field (label above, white field below). Passwords get a
/// show/hide toggle. Every field is >= 48dp tall.
class PsTextField extends StatefulWidget {
  const PsTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.obscure = false,
    this.validator,
    this.inputFormatters,
    this.autofillHints,
    this.onSubmitted,
    this.showLabel = 'Show',
    this.hideLabel = 'Hide',
    this.prefixText,
    this.maxLength,
    this.maxLines = 1,
    this.showCounter = false,
    this.helper,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.below,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final bool obscure;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final String showLabel;
  final String hideLabel;
  final String? prefixText;
  final int? maxLength;
  final int maxLines;
  final bool showCounter;
  final String? helper;
  final bool enabled;
  final TextCapitalization textCapitalization;
  final bool autocorrect;

  /// Shown under the field, e.g. a password strength meter.
  final Widget? below;

  @override
  State<PsTextField> createState() => _PsTextFieldState();
}

class _PsTextFieldState extends State<PsTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(widget.label, style: AppText.label.copyWith(color: AppColors.inkMuted)),
        ),
        const SizedBox(height: AppSpace.s),
        TextFormField(
          controller: widget.controller,
          obscureText: _hidden,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          inputFormatters: widget.inputFormatters,
          autofillHints: widget.autofillHints,
          onFieldSubmitted: widget.onSubmitted,
          maxLength: widget.maxLength,
          maxLines: widget.obscure ? 1 : widget.maxLines,
          minLines: 1,
          enabled: widget.enabled,
          textCapitalization: widget.textCapitalization,
          autocorrect: widget.autocorrect && !widget.obscure,
          enableSuggestions: widget.autocorrect && !widget.obscure,
          style: AppText.bodyStrong,
          cursorColor: AppColors.forest600,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixText: widget.prefixText,
            prefixStyle: AppText.bodyStrong,
            counterText: widget.showCounter ? null : '',
            helperText: widget.helper,
            helperMaxLines: 2,
            suffixIcon: widget.obscure
                ? Semantics(
                    button: true,
                    label: _hidden ? widget.showLabel : widget.hideLabel,
                    child: IconButton(
                      constraints: const BoxConstraints(
                        minWidth: AppSpace.minTouch,
                        minHeight: AppSpace.minTouch,
                      ),
                      icon: Icon(
                        _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.inkMuted,
                      ),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    ),
                  )
                : null,
          ),
        ),
        ?widget.below,
      ],
    );
  }
}
