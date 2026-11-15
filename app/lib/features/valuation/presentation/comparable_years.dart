import '../../../core/localization/localizations.dart';

/// The years of the ads a bike is compared with (N.108): either end may be
/// open; both null means the nearest ads (the same generation, up to 3
/// years apart).
typedef ComparableYears = ({int? from, int? to});

/// Reads the two fields of "Comparar com anúncios de": empty is an open
/// end; null when a year is not a number within [first]..[last] or the
/// range runs backwards.
ComparableYears? parseComparableYears(
  String from,
  String to, {
  required int first,
  required int last,
}) {
  int? read(String text) => text.trim().isEmpty ? null : int.tryParse(text);
  final (f, t) = (read(from), read(to));
  bool bad(String text, int? year) =>
      text.trim().isNotEmpty && (year == null || year < first || year > last);
  if (bad(from, f) || bad(to, t)) return null;
  if (f != null && t != null && f > t) return null;
  return (from: f, to: t);
}

/// "Comparado só com anúncios de 2018 a 2020" (or from / up to one year);
/// null without a range.
String? comparableYearsText(
  ComparableYears years, {
  AppLanguage language = .portuguese,
}) {
  final m = language.messages;
  return switch (years) {
    (from: final f?, to: final t?) => m.comparedYearsBetween(from: f, to: t),
    (from: final f?, to: null) => m.comparedYearsFrom(from: f),
    (from: null, to: final t?) => m.comparedYearsUntil(to: t),
    _ => null,
  };
}
