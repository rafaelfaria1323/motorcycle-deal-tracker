import 'package:intl/intl.dart';

import '../localization/localizations.dart';

abstract final class Formatters {
  static final _prices = {
    for (final language in AppLanguage.values)
      language: NumberFormat.currency(
        locale: language.intlLocale,
        symbol: '€',
        decimalDigits: 0,
      ),
  };
  static final _numbers = {
    for (final language in AppLanguage.values)
      language: NumberFormat.decimalPattern(language.intlLocale),
  };

  static String price(
    double? value, {
    AppLanguage language = AppLanguage.portuguese,
  }) => value == null ? '—' : _prices[language]!.format(value);

  static String decimal(
    num value, {
    int decimals = 1,
    AppLanguage language = AppLanguage.portuguese,
  }) {
    final fixed = value.toStringAsFixed(decimals);
    return language == AppLanguage.portuguese
        ? fixed.replaceAll('.', ',')
        : fixed;
  }

  static String percent(
    num value, {
    int decimals = 0,
    AppLanguage language = AppLanguage.portuguese,
  }) => language.messages.percentage(
    value: decimal(value, decimals: decimals, language: language),
  );

  static String mileage(
    int? value, {
    AppLanguage language = AppLanguage.portuguese,
  }) => value == null ? '—' : '${_numbers[language]!.format(value)} km';

  static String date(DateTime value) {
    final local = value.toLocal();
    return '${_two(local.day)}/${_two(local.month)}/${local.year}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  /// "09:05", local time.
  static String time(DateTime value) {
    final local = value.toLocal();
    return '${_two(local.hour)}:${_two(local.minute)}';
  }

  static double? parsePrice(
    String text, {
    AppLanguage language = AppLanguage.portuguese,
  }) {
    final compact = text.replaceAll(RegExp(r'[\s\u00a0\u202f€]'), '');
    final syntax = language == AppLanguage.portuguese
        ? RegExp(r'^[+-]?(?:\d+|\d{1,3}(?:\.\d{3})+)(?:,\d+)?$')
        : RegExp(r'^[+-]?(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d+)?$');
    if (!syntax.hasMatch(compact)) return null;
    final normalized = language == AppLanguage.portuguese
        ? compact.replaceAll('.', '').replaceAll(',', '.')
        : compact.replaceAll(',', '');
    final value = double.tryParse(normalized);
    return value != null && value.isFinite ? value : null;
  }

  /// Calendar days from [from]'s local day to [to]'s (1 = the next day),
  /// right across a change to or from summer time, when a day has 23 or
  /// 25 hours.
  static int calendarDays(DateTime from, DateTime to) {
    DateTime day(DateTime t) {
      final local = t.toLocal();
      return DateTime.utc(local.year, local.month, local.day);
    }

    return day(to).difference(day(from)).inDays;
  }

  static String daysAgo(
    DateTime value, {
    DateTime? now,
    AppLanguage language = AppLanguage.portuguese,
  }) {
    final days = (now ?? DateTime.now()).difference(value).inDays;
    if (days <= 0) return language.messages.today;
    if (days == 1) return language.messages.yesterday;
    return language.messages.daysAgo(days: days.toString());
  }
}
