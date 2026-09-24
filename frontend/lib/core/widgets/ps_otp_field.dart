import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Six-digit code entry: one hidden input drives six visible boxes, so paste,
/// SMS autofill and backspace all behave. Calls [onCompleted] at 6 digits.
class PsOtpField extends StatefulWidget {
  const PsOtpField({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.length = 6,
    this.hasError = false,
    this.semanticLabel = 'Verification code',
  });

  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final int length;
  final bool hasError;
  final String semanticLabel;

  @override
  State<PsOtpField> createState() => PsOtpFieldState();
}

class PsOtpFieldState extends State<PsOtpField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  void clear() {
    _controller.clear();
    setState(() {});
    _focus.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String v) {
    setState(() {});
    widget.onChanged?.call(v);
    if (v.length == widget.length) widget.onCompleted(v);
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    return Semantics(
      label: widget.semanticLabel,
      textField: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _focus.requestFocus(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(widget.length, (i) {
                final filled = i < text.length;
                final active = _focus.hasFocus && i == text.length.clamp(0, widget.length - 1);
                return Container(
                  width: 46,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.field),
                    border: Border.all(
                      color: widget.hasError
                          ? AppColors.statusDue
                          : active
                              ? AppColors.ink
                              : AppColors.hairline,
                      width: active || widget.hasError ? 1.5 : 1,
                    ),
                  ),
                  child: Text(filled ? text[i] : '', style: AppText.amount),
                );
              }),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.01,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: widget.length,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  onChanged: _changed,
                  decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                  style: const TextStyle(color: Colors.transparent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
