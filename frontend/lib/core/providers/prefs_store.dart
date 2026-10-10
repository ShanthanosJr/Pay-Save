import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small on-device settings (language, text size, privacy switches), so the
/// app opens the way the person left it.
abstract class PrefsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecurePrefsStore implements PrefsStore {
  const SecurePrefsStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: 'ps_pref_$key');
    } catch (_) {
      return null; // a setting that cannot be read falls back to its default
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: 'ps_pref_$key', value: value);
    } catch (_) {
      // the choice still applies for this session
    }
  }
}

class MemoryPrefsStore implements PrefsStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

final prefsStoreProvider = Provider<PrefsStore>((ref) => const SecurePrefsStore());

/// A yes/no setting kept on this phone.
class BoolPref extends Notifier<bool> {
  BoolPref(this.key);

  final String key;

  @override
  bool build() {
    Future.microtask(() async {
      final saved = await ref.read(prefsStoreProvider).read(key);
      if (saved != null) state = saved == 'true';
    });
    return false;
  }

  void set(bool value) {
    state = value;
    ref.read(prefsStoreProvider).write(key, '$value');
  }
}

/// Show "New message" instead of the text in the chat list (shared phones).
final hideChatPreviewsProvider = NotifierProvider<BoolPref, bool>(() => BoolPref('hide_chat_previews'));
