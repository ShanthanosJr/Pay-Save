import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';

/// Headline with one serif-italic accent phrase, as on Foreal ("Start *Dream*").
class AccentTitle extends StatelessWidget {
  const AccentTitle({
    super.key,
    required this.plain,
    required this.accent,
    this.color,
    this.textAlign = TextAlign.start,
    this.large = false,
  });

  final String plain;
  final String accent;
  final Color? color;
  final TextAlign textAlign;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final base = large ? AppText.display : AppText.headline;
    final italic = large ? AppText.displayAccent : AppText.headlineAccent;
    return Semantics(
      header: true,
      label: '$plain $accent',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '$plain ', style: base.copyWith(color: color)),
            TextSpan(text: accent, style: italic.copyWith(color: color)),
          ]),
          textAlign: textAlign,
        ),
      ),
    );
  }
}
