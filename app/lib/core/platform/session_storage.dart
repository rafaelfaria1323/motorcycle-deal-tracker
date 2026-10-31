import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_store.dart';

/// Where Supabase keeps the signed-in session. In the browser, Supabase's
/// own choice (the site's localStorage; null here). In the Android app,
/// encrypted with a key from Android's Keystore instead of the plain
/// SharedPreferences file, moving a session saved there before.
LocalStorage? sessionStorage(String supabaseUrl) => kIsWeb
    ? null
    : _EncryptedSessionStorage(
        // Supabase's own key name, so the earlier session is found.
        'sb-${Uri.parse(supabaseUrl).host.split('.').first}-auth-token',
      );

class _EncryptedSessionStorage(final String _key) extends LocalStorage {
  final _secure = _SecureStore();

  /// Read once at the start; this class is the only writer afterwards.
  String? _session;

  @override
  Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      _session = await loadSession(
        secure: _secure,
        plain: _PlainStore(await SharedPreferences.getInstance()),
        key: _key,
      );
    } on Object {
      // An unreadable store (e.g. the Keystore key gone): start signed out
      // rather than not at all; the app signs in anonymously again.
      _session = null;
    }
  }

  @override
  Future<bool> hasAccessToken() async => _session != null;

  @override
  Future<String?> accessToken() async => _session;

  @override
  Future<void> persistSession(String persistSessionString) async {
    _session = persistSessionString;
    await _secure.write(_key, persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    _session = null;
    await _secure.delete(_key);
  }
}

class _SecureStore implements KeyValueStore {
  // Defaults: AES-GCM data, its key wrapped by an RSA key kept in the
  // Keystore; a store that can't be decrypted is reset, not fatal.
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class _PlainStore(final SharedPreferences _preferences)
    implements KeyValueStore {
  @override
  Future<String?> read(String key) async => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> delete(String key) => _preferences.remove(key);
}
