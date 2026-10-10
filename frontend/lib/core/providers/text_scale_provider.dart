import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs_store.dart';

/// "Display and text size" setting, multiplied into the system text scale.
enum TextSizeChoice {
  standard(1.0),
  enhanced(1.15),
  maximised(1.3);

  const TextSizeChoice(this.factor);
  final double factor;
}

/// Remembered on the phone, so it is still large after the app restarts.
class TextScaleNotifier extends Notifier<TextSizeChoice> {
  static const _key = 'text_size';

  @override
  TextSizeChoice build() {
    Future.microtask(() async {
      final saved = await ref.read(prefsStoreProvider).read(_key);
      final choice = TextSizeChoice.values.where((c) => c.name == saved).firstOrNull;
      if (choice != null) state = choice;
    });
    return TextSizeChoice.standard;
  }

  void set(TextSizeChoice choice) {
    state = choice;
    ref.read(prefsStoreProvider).write(_key, choice.name);
  }
}

final textScaleProvider = NotifierProvider<TextScaleNotifier, TextSizeChoice>(TextScaleNotifier.new);
