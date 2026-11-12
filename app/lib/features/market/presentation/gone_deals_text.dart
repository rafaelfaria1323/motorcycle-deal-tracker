import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import '../domain/entities/gone_deal.dart';
import 'market_behaviour_text.dart';

/// The Deal Score from which a gone ad counts as a good deal: the
/// excellent-opportunity alerts' threshold.
const goodDealMinScore = 80;

/// How many of the good deals the ad's market card lists.
const goneDealsShown = 3;

bool _good(GoneDeal d) => (d.dealScore ?? 0) >= goodDealMinScore;

int _median(List<int> values) {
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : ((sorted[middle - 1] + sorted[middle]) / 2).round();
}

/// How long the model's good deals that likely sold stayed on sale,
/// against the rest of its likely sales (N.68): from [minMarketData]
/// good ones, the median days, and the others' when they are as many.
/// With fewer good ones, only an introduction to the list; none, null.
String? goneDealsLine(
  List<GoneDeal> gone, {
  AppLanguage language = .portuguese,
}) {
  final messages = language.messages;
  final good = [
    for (final d in gone)
      if (_good(d)) d.daysListed,
  ];
  if (good.isEmpty) return null;
  if (good.length < minMarketData) {
    return messages.goneDealsFew(minScore: goodDealMinScore);
  }
  final others = [
    for (final d in gone)
      if (!_good(d)) d.daysListed,
  ];
  final line = messages.goneDealsLine(
    minScore: goodDealMinScore,
    days: _median(good),
    count: good.length,
  );
  if (others.length < minMarketData) return line;
  return '$line ${messages.goneDealsOthers(days: _median(others))}';
}

/// The good deals to list: the quickest to go first, then the latest.
List<GoneDeal> fastGoneDeals(List<GoneDeal> gone) {
  final good = [
    for (final d in gone)
      if (_good(d)) d,
  ];
  good.sort((a, b) {
    final byDays = a.daysListed.compareTo(b.daysListed);
    return byDays != 0 ? byDays : b.goneAt.compareTo(a.goneAt);
  });
  return good.take(goneDealsShown).toList();
}

/// One good deal: "2020 · 20 000 km · 6 000 € · Deal Score 86: 5 dias à
/// venda, saiu há 10 dias".
String goneDealText(
  GoneDeal deal, {
  DateTime? now,
  AppLanguage language = .portuguese,
}) {
  final facts = [
    if (deal.year != null) '${deal.year}',
    if (deal.mileage != null)
      Formatters.mileage(deal.mileage, language: language),
    Formatters.price(deal.price, language: language),
    'Deal Score ${deal.dealScore}',
  ].join(' · ');
  return language.messages.goneDealRow(
    facts: facts,
    days: deal.daysListed,
    when: Formatters.daysAgo(deal.goneAt, now: now, language: language),
  );
}
