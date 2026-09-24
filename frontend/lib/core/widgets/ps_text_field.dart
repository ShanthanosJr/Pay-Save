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
        Text(widget.label, style: AppText.label),
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
          style: AppText.bodyStrong,
          cursorColor: AppColors.ink,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixText: widget.prefixText,
            prefixStyle: AppText.bodyStrong,
            counterText: '',
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
      ],
    );
  }
}
