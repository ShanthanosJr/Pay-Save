import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs_store.dart';

/// The user's chosen app language (design-system §4.1: language is chosen
/// first, on the Welcome screen, and switches the whole app live). It is
/// remembered on the phone, so the app reopens in that language.
class LocaleNotifier extends Notifier<Locale> {
  static const _key = 'language';
  static const _supported = ['en', 'si', 'ta'];

  @override
  Locale build() {
    Future.microtask(() async {
      final saved = await ref.read(prefsStoreProvider).read(_key);
      if (saved != null && _supported.contains(saved)) state = Locale(saved);
    });
    return const Locale('en');
  }

  void set(Locale locale) {
    state = locale;
    ref.read(prefsStoreProvider).write(_key, locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
