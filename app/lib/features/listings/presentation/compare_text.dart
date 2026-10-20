import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import 'listing_labels.dart';
import 'score_explanation.dart';

/// At most this many listings side by side (columns on a phone).
const maxCompared = 3;

/// One row of the comparison: a label, one text per listing ("—" when
/// unknown) and the columns with the best value, if the row has one.
class CompareRow {
  const CompareRow(this.label, this.values, {this.best = const {}});

  final String label;
  final List<String> values;

  /// Indexes of the best values; empty when the row is not a contest, fewer
  /// than two listings have a value, or they are all equal.
  final Set<int> best;
}

/// The indexes holding the best of [values] ([higherIsBetter] or lower).
Set<int> bestOf(List<num?> values, {required bool higherIsBetter}) {
  final known = [
    for (final v in values)
      ?v,
  ];
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

String _marketText(Listing l) {
  final pct = belowMarketPct(l);
  if (pct == null) return '—';
  final rounded = pct.round();
  if (rounded == 0) return 'No valor de mercado';
  return rounded > 0
      ? '$rounded % abaixo do mercado'
      : '${-rounded} % acima do mercado';
}

String _or(Object? value) => value == null ? '—' : '$value';

/// The rows of the comparison, in reading order: what decides first.
List<CompareRow> compareRows(List<Listing> listings, {DateTime? now}) {
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
    row('Preço', (l) => Formatters.price(l.price), score: (l) => l.price),
    row(
      'Pontuação',
      (l) => _or(l.dealScore),
      score: (l) => l.dealScore,
      higherIsBetter: true,
    ),
    row('Risco', (l) => _or(l.riskScore), score: (l) => l.riskScore),
    row(
      'Face ao mercado',
      _marketText,
      score: belowMarketPct,
      higherIsBetter: true,
    ),
    row('Ano', (l) => _or(l.year), score: (l) => l.year, higherIsBetter: true),
    row(
      'Quilometragem',
      (l) => Formatters.mileage(l.mileage),
      score: (l) => l.mileage,
    ),
    row(
      'Baixa de preço',
      (l) => l.hasPriceChanged && l.priceChange! < 0
          ? '−${Formatters.price(-l.priceChange!)}'
          : '—',
    ),
    row(
      'Registos (donos)',
      (l) => _or(l.registrations),
      score: (l) => l.registrations,
    ),
    row(
      'Livro de revisões',
      (l) => switch (l.serviceBook) {
        true => 'Completo',
        false => 'Não',
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
      'Extras',
      (l) => extrasText(l.scoreBreakdown) ?? '—',
      score: (l) => (l.scoreBreakdown?['extras'] as List?)?.length,
      higherIsBetter: true,
    ),
    row('Localização', (l) => l.location ?? '—'),
    row('Vendedor', (l) => l.sellerType.label),
    row('Fonte', (l) => sourceLabel(l.source)),
    row(
      'Visto pela primeira vez',
      (l) => l.firstSeenAt == null
          ? '—'
          : Formatters.daysAgo(l.firstSeenAt!, now: now),
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
