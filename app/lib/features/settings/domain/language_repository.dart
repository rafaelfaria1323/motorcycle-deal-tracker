import '../../../core/localization/app_language.dart';

abstract interface class LanguageRepository {
  AppLanguage cached(String? userId);

  Future<AppLanguage> load(String userId);

  Future<void> save(String userId, AppLanguage language);

  Future<void> remember(String? userId, AppLanguage language);
}
