import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import 'app_language.dart';

export '../../l10n/generated/app_localizations.dart';
export 'app_language.dart';

extension AppLanguageLocalization on AppLanguage {
  Locale get locale => switch (this) {
    AppLanguage.portuguese => const Locale('pt', 'PT'),
    AppLanguage.english => const Locale('en', 'GB'),
  };

  AppLocalizations get messages => _messages[this]!;
}

final _messages = {
  for (final language in AppLanguage.values)
    language: lookupAppLocalizations(language.locale),
};

const appLocales = [Locale('pt', 'PT'), Locale('en', 'GB')];

/// The app's own strings, then the Material, Cupertino and widgets strings
/// of `material_ui` (back, close, date pickers...). The generated
/// [AppLocalizations.localizationsDelegates] still lists the SDK's
/// deprecated `flutter_localizations` ones, which the `material_ui` widgets
/// don't read (N.90).
const appLocalizationsDelegates = <LocalizationsDelegate<Object?>>[
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];

extension LocalizationContext on BuildContext {
  AppLocalizations get strings => AppLocalizations.of(this);

  AppLanguage get language =>
      AppLanguage.fromCode(Localizations.localeOf(this).languageCode);
}
