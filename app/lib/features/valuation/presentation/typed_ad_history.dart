import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import '../../listings/domain/entities/listing.dart' show minRealPrice;

/// What a typed ad's site says of its past (N.109): how many days it has
/// been on sale and its price before a drop; either may be unknown.
typedef TypedAdHistory = ({int? daysListed, double? initialPrice});

/// The longest time on sale that is taken: ten years.
const maxTypedAdDays = 3650;

final _duration = RegExp(
  r'^(?:(?:publicad[oa]|listed)\s+)?(?:há|ha)?\s*(\d{1,4}|um|uma|an?)\s*'
  r'(d|dia|dias|day|days|s|sem|semana|semanas|w|week|weeks|'
  r'm|mes|meses|mês|month|months|a|ano|anos|y|yr|yrs|year|years|'
  r'h|hora|horas|hour|hours|min|mins|minuto|minutos|minute|minutes)?\.?'
  r'\s*(?:ago|atrás|atras)?$',
);

/// How long the ad has been on sale, as typed: days ("35"), or as the
/// sites say it ("5 semanas", "há 2 meses", "3 weeks ago", "1 ano", "a
/// year ago"; a month is 30 days, a year 365; hours and minutes are 0
/// days). `(null,)` when empty; null when it can't be read or is over
/// [maxTypedAdDays].
(int?,)? typedAdDaysValue(String text) {
  final typed = text.trim().toLowerCase();
  if (typed.isEmpty) return (null,);
  final match = _duration.firstMatch(typed);
  if (match == null) return null;
  final number = match.group(1)!;
  final unit = match.group(2);
  // "a" alone is no time: only "a week", "an hour".
  if (int.tryParse(number) == null && unit == null) return null;
  final count = int.tryParse(number) ?? 1;
  final days =
      count *
      switch (unit) {
        's' || 'sem' || 'semana' || 'semanas' || 'w' || 'week' || 'weeks' => 7,
        'm' || 'mes' || 'meses' || 'mês' || 'month' || 'months' => 30,
        'a' ||
        'ano' ||
        'anos' ||
        'y' ||
        'yr' ||
        'yrs' ||
        'year' ||
        'years' => 365,
        'h' ||
        'hora' ||
        'horas' ||
        'hour' ||
        'hours' ||
        'min' ||
        'mins' ||
        'minuto' ||
        'minutos' ||
        'minute' ||
        'minutes' => 0,
        _ => 1,
      };
  return days > maxTypedAdDays ? null : (days,);
}

/// Both fields: null when the time can't be read, or the earlier price is
/// not a price of [minRealPrice] or more above the asking [price] (when
/// that is known).
TypedAdHistory? parseTypedAdHistory(
  String days,
  String initialPrice, {
  required double? price,
  AppLanguage language = .portuguese,
}) {
  final listed = typedAdDaysValue(days);
  if (listed == null) return null;
  if (initialPrice.trim().isEmpty) {
    return (daysListed: listed.$1, initialPrice: null);
  }
  final before = Formatters.parsePrice(initialPrice, language: language);
  if (before == null ||
      before < minRealPrice ||
      (price != null && before <= price)) {
    return null;
  }
  return (daysListed: listed.$1, initialPrice: before);
}
