import 'dart:async';

import 'package:motorcycle_deal_tracker/core/localization/app_language.dart';
import 'package:motorcycle_deal_tracker/features/settings/domain/language_repository.dart';

class LanguageFixture implements LanguageRepository {
  LanguageFixture({this.device = AppLanguage.portuguese});

  AppLanguage device;
  final accounts = <String, AppLanguage>{};
  final cache = <String, AppLanguage>{};
  final loads = <String>[];
  final saves = <(String, AppLanguage)>[];
  final remembered = <(String?, AppLanguage)>[];
  final pendingLoads = <String, Completer<AppLanguage>>{};
  Completer<void>? pendingSave;
  bool failLoad = false;
  bool failSave = false;
  bool failCache = false;

  @override
  AppLanguage cached(String? userId) =>
      userId == null ? device : cache[userId] ?? AppLanguage.portuguese;

  @override
  Future<AppLanguage> load(String userId) async {
    loads.add(userId);
    if (failLoad) throw StateError('Offline');
    final pending = pendingLoads.remove(userId);
    return pending == null
        ? accounts[userId] ?? AppLanguage.portuguese
        : pending.future;
  }

  @override
  Future<void> save(String userId, AppLanguage language) async {
    saves.add((userId, language));
    await pendingSave?.future;
    if (failSave) throw StateError('Offline');
    accounts[userId] = language;
  }

  @override
  Future<void> remember(String? userId, AppLanguage language) async {
    if (failCache) throw StateError('Storage unavailable');
    remembered.add((userId, language));
    device = language;
    if (userId != null) cache[userId] = language;
  }
}
