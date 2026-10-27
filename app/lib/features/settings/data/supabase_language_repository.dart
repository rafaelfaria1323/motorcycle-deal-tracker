import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/localization/app_language.dart';
import '../domain/language_repository.dart';

class SupabaseLanguageRepository implements LanguageRepository {
  SupabaseLanguageRepository(this._client, this._preferences);

  final SupabaseClient _client;
  final SharedPreferences _preferences;

  static const deviceKey = 'app_language';

  static String _key(String? userId) =>
      userId == null ? deviceKey : 'account_language:$userId';

  @override
  AppLanguage cached(String? userId) => AppLanguage.fromCode(
    _preferences.getString(_key(userId)) ?? AppLanguage.portuguese.code,
  );

  @override
  Future<AppLanguage> load(String userId) async {
    final row = await _client
        .from('account_languages')
        .select('language')
        .eq('user_id', userId)
        .maybeSingle();
    return row == null
        ? AppLanguage.portuguese
        : AppLanguage.fromCode(row['language'] as String);
  }

  @override
  Future<void> save(String userId, AppLanguage language) async {
    await _client.from('account_languages').upsert({
      'user_id': userId,
      'language': language.code,
    }, onConflict: 'user_id');
  }

  @override
  Future<void> remember(String? userId, AppLanguage language) async {
    final saved = await Future.wait([
      _preferences.setString(deviceKey, language.code),
      if (userId != null) _preferences.setString(_key(userId), language.code),
    ]);
    if (saved.contains(false)) {
      throw StateError('Could not cache the language preference');
    }
  }
}
