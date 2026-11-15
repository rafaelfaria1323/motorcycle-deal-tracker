import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import '../../listings/domain/entities/listing.dart' show minRealPrice;

/// What a typed ad's site says of its past (N.109): how many days it has
/// been on sale and its price before a drop; either may be unknown.
typedef TypedAdHistory = ({int? daysListed, double? initialPrice});

/// The longest time on sale that is taken: ten years.
const maxTypedAdDays = 3650;

final _duration = RegExp(
  r'^(\d{1,4})\s*(d|dia|dias|day|days|s|sem|semana|semanas|w|week|weeks|'
  r'm|mes|meses|mês|month|months)?\.?$',
);

/// How long the ad has been on sale, as typed: days ("35"), or weeks and
/// months as the sites say them ("5 semanas", "2 meses", "3 weeks"; a
/// month is 30 days). `(null,)` when empty; null when it can't be read or
/// is over [maxTypedAdDays].
(int?,)? typedAdDaysValue(String text) {
  final typed = text.trim().toLowerCase();
  if (typed.isEmpty) return (null,);
  final match = _duration.firstMatch(typed);
  if (match == null) return null;
  final count = int.parse(match.group(1)!);
  final days =
      count *
      switch (match.group(2)) {
        's' || 'sem' || 'semana' || 'semanas' || 'w' || 'week' || 'weeks' => 7,
        'm' || 'mes' || 'meses' || 'mês' || 'month' || 'months' => 30,
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
