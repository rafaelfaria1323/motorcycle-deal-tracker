enum AppLanguage {
  portuguese('pt', 'pt_PT'),
  english('en', 'en_GB');

  const AppLanguage(this.code, this.intlLocale);

  final String code;
  final String intlLocale;

  static AppLanguage fromCode(String code) => values.firstWhere(
    (language) => language.code == code,
    orElse: () => throw FormatException('Unsupported app language: $code'),
  );
}
