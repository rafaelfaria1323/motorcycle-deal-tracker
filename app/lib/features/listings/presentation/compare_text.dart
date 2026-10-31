import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import 'listing_card_text.dart';
import 'listing_labels.dart';
import 'score_explanation.dart';
import '../../../core/localization/localizations.dart';

/// At most this many listings side by side (columns on a phone).
const maxCompared = 3;

/// One row of the comparison: a label, one text per listing ("—" when
/// unknown) and the columns with the best value, if the row has one.
class const CompareRow(
  final String label,
  final List<String> values, {

  /// Indexes of the best values; empty when the row is not a contest, fewer
  /// than two listings have a value, or they are all equal.
  final Set<int> best = const {},
});

/// The indexes holding the best of [values] ([higherIsBetter] or lower).
Set<int> bestOf(List<num?> values, {required bool higherIsBetter}) {
  final known = [for (final v in values) ?v];
  if (known.length < 2) return const {};
  final top = known.reduce(
    (a, b) => higherIsBetter ? (a >= b ? a : b) : (a <= b ? a : b),
  );
  if (known.every((v) => v == top)) return const {};
  return {
    for (var i = 0; i < values.length; i++)
      if (values[i] == top) i,
  };
}

/// How far below (+) or above (−) the estimated market value the price is.
double? belowMarketPct(Listing l) =>
    (l.scoreBreakdown?['pct_below_market'] as num?)?.toDouble();

String _marketText(Listing l, {AppLanguage language = .portuguese}) =>
    marketPositionText(belowMarketPct(l), language: language) ?? '—';

String _or(Object? value) => value == null ? '—' : '$value';

/// The rows of the comparison, in reading order: what decides first.
List<CompareRow> compareRows(
  List<Listing> listings, {
  DateTime? now,
  AppLanguage language = .portuguese,
}) {
  CompareRow row(
    String label,
    String Function(Listing) text, {
    num? Function(Listing)? score,
    bool higherIsBetter = false,
  }) => CompareRow(
    label,
    [for (final l in listings) text(l)],
    best: score == null
        ? const {}
        : bestOf([
            for (final l in listings) score(l),
          ], higherIsBetter: higherIsBetter),
  );

  return [
    row(
      language.messages.price,
      (l) => l.priceLabel(language: language),
      score: (l) => l.askingPrice,
    ),
    row(
      language.messages.score,
      (l) => _or(l.dealScore),
      score: (l) => l.dealScore,
      higherIsBetter: true,
    ),
    row(
      language.messages.risk,
      (l) => _or(l.riskScore),
      score: (l) => l.riskScore,
    ),
    row(
      language.messages.againstMarket,
      (value0) => _marketText(value0, language: language),
      score: belowMarketPct,
      higherIsBetter: true,
    ),
    row(
      language.messages.yearCompareText,
      (l) => _or(l.year),
      score: (l) => l.year,
      higherIsBetter: true,
    ),
    row(
      language.messages.mileage,
      (l) => Formatters.mileage(l.mileage, language: language),
      score: (l) => l.mileage,
    ),
    row(
      language.messages.priceDrop,
      (l) => l.hasPriceChanged && l.priceChange! < 0
          ? '−${Formatters.price(-l.priceChange!, language: language)}'
          : '—',
    ),
    row(
      language.messages.registeredOwners,
      (l) => _or(l.registrations),
      score: (l) => l.registrations,
    ),
    row(
      language.messages.serviceBook,
      (l) => switch (l.serviceBook) {
        true => language.messages.complete,
        false => language.messages.no,
        null => '—',
      },
      score: (l) => switch (l.serviceBook) {
        true => 1,
        false => 0,
        null => null,
      },
      higherIsBetter: true,
    ),
    row(
      language.messages.extras,
      (l) => extrasText(l.scoreBreakdown, language: language) ?? '—',
      score: (l) => (l.scoreBreakdown?['extras'] as List?)?.length,
      higherIsBetter: true,
    ),
    row(language.messages.locationCompareText, (l) => l.location ?? '—'),
    row(
      language.messages.seller,
      (l) => l.sellerType.label(language: language),
    ),
    row(
      language.messages.source,
      (l) => sourceLabel(l.source, language: language),
    ),
    row(
      language.messages.firstSeen,
      (l) => l.firstSeenAt == null
          ? '—'
          : Formatters.daysAgo(l.firstSeenAt!, now: now, language: language),
    ),
  ];
}

/// "?ids=a,b,c" -> ["a", "b", "c"], without repeats, at most [maxCompared].
List<String> parseCompareIds(String? ids) {
  final seen = <String>{};
  return [
    for (final id in (ids ?? '').split(','))
      if (id.trim().isNotEmpty && seen.add(id.trim())) id.trim(),
  ].take(maxCompared).toList();
}
