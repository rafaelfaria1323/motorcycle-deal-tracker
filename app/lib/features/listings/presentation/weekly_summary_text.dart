import '../../../core/formatting/formatters.dart';
import '../domain/entities/weekly_summary.dart';

String _day(DateTime t) =>
    '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}';

String _count(int n, String one, String many) => '$n ${n == 1 ? one : many}';

/// "De 12/10 a 18/10": the 7 days, the last one included.
String summaryPeriodText(WeeklySummary s) =>
    'De ${_day(s.since)} a ${_day(s.until.subtract(const Duration(days: 1)))}';

/// The week's counts, one line each.
List<String> summaryCountLines(WeeklySummary s) => [
  _count(s.newCount, 'anúncio novo', 'anúncios novos'),
  _count(s.dropCount, 'baixa de preço', 'baixas de preço'),
  _count(s.goneCount, 'saiu do mercado', 'saíram do mercado'),
  _count(s.liveCount, 'anúncio ativo', 'anúncios ativos'),
];

/// "Yamaha MT-07 2, Honda CB650R 1"; null without new listings.
String? newByModelText(WeeklySummary s) => s.newByModel.isEmpty
    ? null
    : s.newByModel.map((m) => '${m.bike} ${m.count}').join(', ');

/// "Yamaha MT-07 2021".
String summaryDealTitle(SummaryDeal d) =>
    [d.bike, if (d.year != null) '${d.year}'].join(' ');

/// A best deal: price, mileage and Deal Score.
String bestDealText(SummaryDeal d) => [
  if (d.price != null) Formatters.price(d.price),
  if (d.mileage != null) Formatters.mileage(d.mileage),
  if (d.dealScore != null) 'Pontuação ${d.dealScore}',
].join(' · ');

/// A price drop: "7 500 € → 7 200 € (−4 %)".
String priceDropText(SummaryDeal d) {
  final old = d.oldPrice;
  final now = d.price;
  if (old == null || now == null || old <= 0) return Formatters.price(now);
  final percent = Formatters.percent((old - now) / old * 100);
  return '${Formatters.price(old)} → ${Formatters.price(now)} (−$percent)';
}

/// When the summary was made, for the page's footnote.
String summaryMadeText(WeeklySummary s) =>
    'Feito a ${Formatters.date(s.madeAt)} às ${Formatters.time(s.madeAt)}, '
    'com os seus modelos acompanhados. Chega todas as segundas-feiras de '
    'manhã aos aparelhos com notificações ativas.';
