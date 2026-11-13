import '../../../core/formatting/formatters.dart';
import '../../listings/domain/entities/listing.dart';
import '../../listings/presentation/bike_specs_text.dart';
import '../../listings/presentation/listing_card_text.dart';
import '../../listings/presentation/listing_labels.dart';
import '../../listings/presentation/score_explanation.dart';
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
      language.messages.yearLabel,
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
    ..._specRows(listings, row, language),
    row(language.messages.locationLabel, (l) => l.location ?? '—'),
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

typedef _Row = CompareRow Function(
  String label,
  String Function(Listing) text, {
  num? Function(Listing)? score,
  bool higherIsBetter,
});

/// The model's figures (N.75), each only when some listing has it: more
/// power and range, less weight and consumption are better; seat height
/// and tank only inform.
List<CompareRow> _specRows(
  List<Listing> listings,
  _Row row,
  AppLanguage language,
) {
  final m = language.messages;
  String decimal(num? value, String unit) => value == null
      ? '—'
      : '${Formatters.decimal(value.toDouble(), decimals: value % 1 == 0 ? 0 : 1, language: language)} $unit';
  double? fuel(Listing l) => l.maintenance?.fuelPer100Km;
  int? range(Listing l) => rangeKm(l.specs?.tankLitres, fuel(l));
  final specs =
      <(String, num? Function(Listing), String Function(Listing), bool?)>[
        (
          m.specPower,
          (l) => l.specs?.powerKw,
          (l) => switch (l.specs?.powerKw) {
            final kw? => powerText(kw, language: language),
            null => '—',
          },
          true,
        ),
        (
          m.specWeight,
          (l) => l.specs?.weightKg,
          (l) => decimal(l.specs?.weightKg, 'kg'),
          false,
        ),
        (
          m.specSeatHeight,
          (l) => l.specs?.seatHeightMm,
          (l) => decimal(l.specs?.seatHeightMm, 'mm'),
          null,
        ),
        (
          m.specTank,
          (l) => l.specs?.tankLitres,
          (l) => decimal(l.specs?.tankLitres, 'l'),
          null,
        ),
        (m.specConsumption, fuel, (l) => decimal(fuel(l), 'l/100 km'), false),
        (
          m.specRange,
          range,
          (l) => switch (range(l)) {
            final km? => Formatters.mileage(km, language: language),
            null => '—',
          },
          true,
        ),
      ];
  return [
    for (final (label, value, text, higherIsBetter) in specs)
      if (listings.any((l) => value(l) != null))
        higherIsBetter == null
            ? row(label, text)
            : row(label, text, score: value, higherIsBetter: higherIsBetter),
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
