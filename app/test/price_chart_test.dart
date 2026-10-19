import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/price_point.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/price_chart.dart';

PricePoint at(int day, double price) =>
    PricePoint(price: price, observedAt: DateTime.utc(2026, 10, day));

void main() {
  test('no chart without a change', () {
    expect(priceChart([at(1, 7000)], now: DateTime.utc(2026, 10, 11)), isNull);
    expect(priceChart(const [], now: DateTime.utc(2026, 10, 11)), isNull);
  });

  test('time runs from the first price to now, each price holds', () {
    final chart = priceChart(
      [at(6, 6500), at(1, 7000)], // any order
      now: DateTime.utc(2026, 10, 11),
    )!;

    expect(chart.start, DateTime.utc(2026, 10, 1));
    expect([for (final p in chart.line) p.x], [0, 0.5, 0.5, 1]);
    // 7000 holds until day 6, then 6500 until now.
    expect(chart.line[0].y, chart.line[1].y);
    expect(chart.line[2].y, chart.line[3].y);
    expect(chart.line[0].y, greaterThan(chart.line[3].y));
    expect([for (final p in chart.changes) p.x], [0, 0.5]);
  });

  test('labels sit on the highest and lowest prices, inside the chart', () {
    final chart = priceChart([
      at(1, 7000),
      at(3, 6800),
      at(5, 6500),
    ], now: DateTime.utc(2026, 10, 9))!;

    expect(chart.highest, 7000);
    expect(chart.lowest, 6500);
    expect(chart.highestY, chart.line.first.y);
    expect(chart.lowestY, chart.line.last.y);
    expect(chart.highestY, lessThan(1));
    expect(chart.lowestY, greaterThan(0));
    expect(chart.reference, isNull);
  });

  test("the site's earlier price is drawn above ours", () {
    final chart = priceChart(
      [at(1, 7000), at(5, 6500)],
      now: DateTime.utc(2026, 10, 9),
      siteBefore: 7500,
    )!;

    expect(chart.reference, 7500);
    expect(chart.highest, 7000);
    expect(chart.referenceY, greaterThan(chart.highestY));
    expect(chart.referenceY, lessThan(1));
  });

  test('a site price below ours is left out', () {
    final chart = priceChart(
      [at(1, 7000), at(5, 6500)],
      now: DateTime.utc(2026, 10, 9),
      siteBefore: 6900,
    )!;

    expect(chart.reference, isNull);
  });

  test('changes within minutes still spread over a day', () {
    final start = DateTime.utc(2026, 10, 1, 10);
    final chart = priceChart([
      PricePoint(price: 7000, observedAt: start),
      PricePoint(price: 6900, observedAt: start.add(const Duration(hours: 6))),
    ], now: start.add(const Duration(hours: 6)))!;

    expect(chart.changes.last.x, 0.25);
    expect(chart.line.last.x, 1);
  });

  test('a flat history still has room above and below', () {
    final chart = priceChart([
      at(1, 7000),
      at(5, 7000),
    ], now: DateTime.utc(2026, 10, 9))!;

    expect(chart.highestY, inExclusiveRange(0, 1));
  });
}
