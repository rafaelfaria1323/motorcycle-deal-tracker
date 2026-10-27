enum AppLanguage {
  portuguese('pt', 'pt_PT'),
  english('en', 'en_GB');

  const AppLanguage(this.code, this.intlLocale);

  final String code;
  final String intlLocale;

  static AppLanguage fromCode(String code) =>
      tryFromCode(code) ??
      (throw FormatException('Unsupported app language: $code'));

  /// The language of [code], or null when this build has no such language.
  static AppLanguage? tryFromCode(String? code) =>
      values.where((language) => language.code == code).firstOrNull;
}
