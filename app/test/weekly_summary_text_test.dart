import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/models/weekly_summary_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/weekly_summary.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/weekly_summary_text.dart';

/// A row as the collector writes it (weeklySummaryJson).
final row = {
  'made_at': '2026-10-19T07:53:10Z',
  'summary': {
    'since': '2026-10-12T07:52:00Z',
    'until': '2026-10-19T07:52:00Z',
    'live': 4,
    'new': 3,
    'gone': 1,
    'drops': 1,
    'new_by_model': [
      {'bike': 'Yamaha MT-07', 'count': 2},
      {'bike': 'Honda CB650R', 'count': 1},
    ],
    'biggest_drops': [
      {
        'id': 'n1',
        'bike': 'Honda CB650R',
        'year': 2021,
        'mileage': 12000,
        'price': 7200,
        'deal_score': null,
        'old_price': 7500,
      },
    ],
    'best': [
      {
        'id': 'a',
        'bike': 'Yamaha MT-07',
        'year': null,
        'mileage': null,
        'price': 6900,
        'deal_score': 88,
      },
      'not a listing',
    ],
  },
};

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  final summary = WeeklySummaryModel.fromJson(row);

  test('reads the row the collector writes', () {
    expect(summary.newCount, 3);
    expect(summary.liveCount, 4);
    expect(summary.newByModel.first, (bike: 'Yamaha MT-07', count: 2));
    expect(summary.biggestDrops.single.oldPrice, 7500);
    expect(summary.bestDeals.single.listingId, 'a');
  });

  test('an empty week reads as zeros', () {
    final empty = WeeklySummaryModel.fromJson({
      'made_at': '2026-10-19T07:53:10Z',
      'summary': {
        'since': '2026-10-12T07:52:00Z',
        'until': '2026-10-19T07:52:00Z',
      },
    });
    expect(summaryCountLines(empty), [
      '0 anúncios novos',
      '0 baixas de preço',
      '0 saíram do mercado',
      '0 anúncios ativos',
    ]);
    expect(newByModelText(empty), isNull);
  });

  test('the period names the last day included', () {
    expect(summaryPeriodText(summary), 'De 12/10 a 18/10');
  });

  test('counts, singular and plural', () {
    expect(summaryCountLines(summary), [
      '3 anúncios novos',
      '1 baixa de preço',
      '1 saiu do mercado',
      '4 anúncios ativos',
    ]);
    expect(newByModelText(summary), 'Yamaha MT-07 2, Honda CB650R 1');
  });

  test('deals leave out what the listing lacks', () {
    final best = summary.bestDeals.single;
    expect(summaryDealTitle(best), 'Yamaha MT-07');
    expect(bestDealText(best), '${Formatters.price(6900)} · Pontuação 88');
    expect(summaryDealTitle(summary.biggestDrops.single), 'Honda CB650R 2021');
  });

  test('a drop shows both prices and the share', () {
    expect(
      priceDropText(summary.biggestDrops.single),
      '${Formatters.price(7500)} → ${Formatters.price(7200)} (−4 %)',
    );
    expect(
      priceDropText(const SummaryDeal(listingId: 'x', bike: 'B', price: 10)),
      Formatters.price(10),
    );
  });

  test('the footnote says when it was made', () {
    expect(summaryMadeText(summary), startsWith('Feito a 19/10/2026 às '));
  });
}
