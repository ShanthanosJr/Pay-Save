import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Display and text size" setting, multiplied into the system text scale.
enum TextSizeChoice {
  standard(1.0),
  enhanced(1.15),
  maximised(1.3);

  const TextSizeChoice(this.factor);
  final double factor;
}

class TextScaleNotifier extends Notifier<TextSizeChoice> {
  @override
  TextSizeChoice build() => TextSizeChoice.standard;

  void set(TextSizeChoice choice) => state = choice;
}

final textScaleProvider = NotifierProvider<TextScaleNotifier, TextSizeChoice>(TextScaleNotifier.new);
