import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/alerts_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/colour_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/dashboard_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/saved_search_summary.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/score_explanation.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/viewing_checklist.dart';
import 'package:motorcycle_deal_tracker/features/settings/presentation/language_cubit.dart';

import '../integration_test/support/language_fixture.dart';
import 'helpers/session_fixture.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'supported languages have stable codes and explicit regional formats',
    () {
      expect(AppLanguage.fromCode('pt'), AppLanguage.portuguese);
      expect(AppLanguage.fromCode('en'), AppLanguage.english);
      expect(AppLanguage.portuguese.intlLocale, 'pt_PT');
      expect(AppLanguage.english.intlLocale, 'en_GB');
      expect(() => AppLanguage.fromCode('fr'), throwsFormatException);
      expect(AppLanguage.tryFromCode('en'), AppLanguage.english);
      expect(AppLanguage.tryFromCode('fr'), isNull);
      expect(AppLanguage.tryFromCode(null), isNull);
    },
  );

  test(
    'both resource catalogs are complete and have matching placeholders',
    () {
      Map<String, dynamic> catalog(String code) =>
          jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
              as Map<String, dynamic>;
      final pt = catalog('pt');
      final en = catalog('en');
      Set<String> keys(Map<String, dynamic> values) =>
          values.keys.where((key) => !key.startsWith('@')).toSet();
      expect(keys(en), keys(pt));
      expect(keys(pt).length, greaterThan(900));
      // A plural branch's text ("=1{Problema}") is not a placeholder.
      final arguments = RegExp(
        r'(?<!=\d+|zero|one|two|few|many|other)\{([A-Za-z]\w*)(?:[,}])',
      );
      for (final key in keys(pt)) {
        final portuguese = pt[key] as String;
        final english = en[key] as String;
        expect(portuguese.trim(), isNotEmpty, reason: key);
        expect(english.trim(), isNotEmpty, reason: key);
        expect(pt['@$key'], isA<Map<String, dynamic>>(), reason: key);
        Set<String> placeholders(String text) =>
            arguments.allMatches(text).map((match) => match[1]!).toSet();
        expect(placeholders(english), placeholders(portuguese), reason: key);
      }
    },
  );

  test('count messages handle zero, one and several in both languages', () {
    const pt = AppLanguage.portuguese;
    const en = AppLanguage.english;
    for (final (count, expectedPt, expectedEn) in [
      (0, '0 anúncios', '0 listings'),
      (1, '1 anúncio', '1 listing'),
      (4, '4 anúncios', '4 listings'),
    ]) {
      expect(
        listingsResultsText(count, hasMore: false, language: pt),
        expectedPt,
      );
      expect(
        listingsResultsText(count, hasMore: false, language: en),
        expectedEn,
      );
    }
    expect(
      listingsResultsText(1, hasMore: true, language: pt),
      '1 anúncio carregado',
    );
    expect(
      listingsResultsText(4, hasMore: true, language: pt),
      '4 anúncios carregados',
    );
    expect(
      listingsResultsText(1, hasMore: true, language: en),
      '1 listing loaded',
    );
    expect(unreadAlertsText(0, language: pt), 'Tudo lido');
    expect(unreadAlertsText(0, language: en), 'All read');
    expect(unreadAlertsText(1, language: en), '1 unread alert');
    expect(unreadAlertsText(5, language: en), '5 unread alerts');
    expect(searchMatchesText(0, language: en), '0 matching listings');
    expect(searchMatchesText(1, language: en), '1 matching listing');
    expect(searchMatchesText(5, language: en), '5 matching listings');
  });

  test(
    'localized label collections stay immutable and cached per language',
    () {
      for (final language in AppLanguage.values) {
        final colours = colourLabels(language: language);
        expect(identical(colours, colourLabels(language: language)), isTrue);
        expect(colours['black'], language.messages.black);
        expect(() => colours['black'] = 'changed', throwsUnsupportedError);

        final extras = extraLabels(language: language);
        expect(identical(extras, extraLabels(language: language)), isTrue);
        expect(extras['exhaust'], language.messages.sportsExhaust);
        expect(extras.clear, throwsUnsupportedError);

        final checklist = viewingChecklist(language: language);
        expect(
          identical(checklist, viewingChecklist(language: language)),
          isTrue,
        );
        expect(checklist.first.title, language.messages.documents);
        expect(checklist.clear, throwsUnsupportedError);
        expect(() => checklist.first.items.clear(), throwsUnsupportedError);
        final items = viewingChecklistItems(language: language);
        expect(
          identical(items, viewingChecklistItems(language: language)),
          isTrue,
        );
        expect(items.clear, throwsUnsupportedError);
      }
      expect(
        colourLabels(language: AppLanguage.english),
        isNot(same(colourLabels())),
      );
      expect(
        viewingChecklistItems(
          language: AppLanguage.english,
        ).map((item) => item.key),
        viewingChecklistItems().map((item) => item.key),
      );
    },
  );

  test(
    'anonymous language choices persist locally without an account write',
    () async {
      final session = SessionFixture(accountId: null);
      final repository = LanguageFixture();
      final cubit = session.track(LanguageCubit(repository, session.cubit));
      expect(cubit.state.language, AppLanguage.portuguese);
      expect(await cubit.select(AppLanguage.english), isTrue);
      expect(cubit.state.language, AppLanguage.english);
      expect(repository.device, AppLanguage.english);
      expect(repository.loads, isEmpty);
      expect(repository.saves, isEmpty);
      expect(repository.remembered, [(null, AppLanguage.english)]);
      final reopened = session.track(LanguageCubit(repository, session.cubit));
      expect(reopened.state.language, AppLanguage.english);
    },
  );

  test(
    'an account restores its cached language before loading its own choice',
    () async {
      final session = SessionFixture();
      final repository = LanguageFixture()
        ..cache['owner'] = AppLanguage.english
        ..accounts['owner'] = AppLanguage.portuguese;
      final pending = Completer<AppLanguage>();
      repository.pendingLoads['owner'] = pending;
      final cubit = session.track(LanguageCubit(repository, session.cubit));
      expect(cubit.state.language, AppLanguage.english);
      expect(cubit.state.loading, isTrue);
      pending.complete(AppLanguage.portuguese);
      await _settle();
      expect(cubit.state, const LanguageState());
      expect(repository.cache['owner'], AppLanguage.portuguese);
    },
  );

  test('legacy accounts retain Portuguese even on an English device', () async {
    final session = SessionFixture();
    final repository = LanguageFixture(device: AppLanguage.english);
    final cubit = session.track(LanguageCubit(repository, session.cubit));
    await _settle();
    expect(cubit.state, const LanguageState());
    expect(repository.loads, ['owner']);
  });

  test(
    'account choices are saved remotely and cached for offline use',
    () async {
      final session = SessionFixture();
      final repository = LanguageFixture();
      final cubit = session.track(LanguageCubit(repository, session.cubit));
      await _settle();
      expect(await cubit.select(AppLanguage.english), isTrue);
      expect(repository.saves, [('owner', AppLanguage.english)]);
      expect(repository.accounts['owner'], AppLanguage.english);
      expect(repository.cache['owner'], AppLanguage.english);
      expect(cubit.state.language, AppLanguage.english);
      await session.changeAccount(null);
      expect(cubit.state.language, AppLanguage.english);
      expect(repository.loads, ['owner']);
    },
  );

  test(
    'a failed load keeps the cached language and reports a retryable failure',
    () async {
      final session = SessionFixture();
      final repository = LanguageFixture()
        ..cache['owner'] = AppLanguage.english
        ..failLoad = true;
      final cubit = session.track(LanguageCubit(repository, session.cubit));
      await _settle();
      expect(cubit.state.language, AppLanguage.english);
      expect(cubit.state.failure, LanguageFailure.load);
      repository
        ..failLoad = false
        ..accounts['owner'] = AppLanguage.portuguese;
      await cubit.load();
      expect(cubit.state, const LanguageState());
    },
  );

  test(
    'failed remote or local saves never report a successful change',
    () async {
      final session = SessionFixture();
      final repository = LanguageFixture();
      final cubit = session.track(LanguageCubit(repository, session.cubit));
      await _settle();
      repository.failSave = true;
      expect(await cubit.select(AppLanguage.english), isFalse);
      expect(cubit.state.language, AppLanguage.portuguese);
      expect(cubit.state.failure, LanguageFailure.save);
      expect(repository.cache['owner'], AppLanguage.portuguese);
      repository
        ..failSave = false
        ..failCache = true;
      expect(await cubit.select(AppLanguage.english), isFalse);
      expect(cubit.state.failure, LanguageFailure.save);
      repository.failCache = false;
      expect(await cubit.select(AppLanguage.english), isTrue);
      expect(cubit.state.language, AppLanguage.english);
      expect(cubit.state.failure, isNull);
    },
  );

  test(
    'the language cannot be saved while loading or already saving',
    () async {
      final session = SessionFixture();
      final repository = LanguageFixture();
      final pending = Completer<AppLanguage>();
      repository.pendingLoads['owner'] = pending;
      final cubit = session.track(LanguageCubit(repository, session.cubit));
      expect(await cubit.select(AppLanguage.english), isFalse);
      pending.complete(AppLanguage.portuguese);
      await _settle();
      final save = Completer<void>();
      repository.pendingSave = save;
      final selecting = cubit.select(AppLanguage.english);
      expect(cubit.state.saving, isTrue);
      expect(await cubit.select(AppLanguage.portuguese), isFalse);
      await cubit.load();
      expect(repository.loads, ['owner']);
      save.complete();
      expect(await selecting, isTrue);
      expect(repository.saves, [('owner', AppLanguage.english)]);
    },
  );

  test(
    'older loads cannot overwrite a refreshed or different account',
    () async {
      final session = SessionFixture();
      final repository = LanguageFixture();
      final old = Completer<AppLanguage>();
      repository.pendingLoads['owner'] = old;
      final cubit = session.track(LanguageCubit(repository, session.cubit));
      await cubit.load();
      old.complete(AppLanguage.english);
      await _settle();
      expect(cubit.state.language, AppLanguage.portuguese);
      expect(repository.remembered, [('owner', AppLanguage.portuguese)]);

      final pending = Completer<AppLanguage>();
      repository.pendingLoads['owner'] = pending;
      final loading = cubit.load();
      await session.changeAccount('other');
      await session.changeAccount('owner');
      pending.complete(AppLanguage.english);
      await loading;
      expect(cubit.state.language, AppLanguage.portuguese);
      expect(repository.cache['owner'], AppLanguage.portuguese);
    },
  );

  test(
    'a save for the old account cannot change the new account language',
    () async {
      final session = SessionFixture();
      final repository = LanguageFixture();
      final cubit = session.track(LanguageCubit(repository, session.cubit));
      await _settle();
      final pending = Completer<void>();
      repository.pendingSave = pending;
      final saving = cubit.select(AppLanguage.english);
      await session.changeAccount('other');
      pending.complete();
      expect(await saving, isFalse);
      expect(cubit.state.language, AppLanguage.portuguese);
      expect(repository.cache['other'], AppLanguage.portuguese);
      expect(repository.cache['owner'], AppLanguage.portuguese);
      expect(repository.saves, [('owner', AppLanguage.english)]);
    },
  );

  test('closing ignores a pending account load', () async {
    final session = SessionFixture();
    final repository = LanguageFixture();
    final pending = Completer<AppLanguage>();
    repository.pendingLoads['owner'] = pending;
    final cubit = session.track(LanguageCubit(repository, session.cubit));
    await cubit.close();
    pending.complete(AppLanguage.english);
    await _settle();
    expect(repository.remembered, isEmpty);
  });
}
