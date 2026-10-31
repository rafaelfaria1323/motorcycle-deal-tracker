import '../../../core/formatting/formatters.dart';
import '../domain/entities/weekly_summary.dart';
import '../../../core/localization/localizations.dart';

String _day(DateTime t) =>
    '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}';

/// "De 12/10 a 18/10": the 7 days, the last one included.
String summaryPeriodText(
  WeeklySummary s, {
  AppLanguage language = .portuguese,
}) => language.messages.fromTo(
  from: _day(s.since),
  to: _day(s.until.subtract(const Duration(days: 1))),
);

/// The week's counts, one line each.
List<String> summaryCountLines(
  WeeklySummary s, {
  AppLanguage language = .portuguese,
}) => [
  language.messages.newListingCount(count: s.newCount),
  language.messages.priceDropCount(count: s.dropCount),
  language.messages.leftMarketCount(count: s.goneCount),
  language.messages.activeListingCount(count: s.liveCount),
];

/// "Yamaha MT-07 2, Honda CB650R 1"; null without new listings.
String? newByModelText(WeeklySummary s) => s.newByModel.isEmpty
    ? null
    : s.newByModel.map((m) => '${m.bike} ${m.count}').join(', ');

/// "Yamaha MT-07 2021".
String summaryDealTitle(SummaryDeal d) =>
    [d.bike, if (d.year != null) '${d.year}'].join(' ');

/// A best deal: price, mileage and Deal Score.
String bestDealText(SummaryDeal d, {AppLanguage language = .portuguese}) => [
  if (d.price != null) Formatters.price(d.price, language: language),
  if (d.mileage != null) Formatters.mileage(d.mileage, language: language),
  if (d.dealScore != null)
    language.messages.scoreWeeklySummaryText(dealScore: d.dealScore.toString()),
].join(' · ');

/// A price drop: "7 500 € → 7 200 € (−4 %)".
String priceDropText(SummaryDeal d, {AppLanguage language = .portuguese}) {
  final old = d.oldPrice;
  final now = d.price;
  if (old == null || now == null || old <= 0) {
    return Formatters.price(now, language: language);
  }
  final percent = Formatters.percent(
    (old - now) / old * 100,
    language: language,
  );
  return '${Formatters.price(old, language: language)} → ${Formatters.price(now, language: language)} (−$percent)';
}

/// When the summary was made, for the page's footnote.
String summaryMadeText(WeeklySummary s, {AppLanguage language = .portuguese}) =>
    language.messages.weeklySummaryCreated(
      date: Formatters.date(s.madeAt),
      time: Formatters.time(s.madeAt),
    );
