import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/price_point.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/price_chart.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/price_history.dart';

PricePoint at(int day, double price) =>
    PricePoint(price: price, observedAt: DateTime.utc(2026, 10, day));

void main() {
  test('no chart without a change', () {
    expect(priceChart([at(1, 7000)], now: DateTime.utc(2026, 10, 11)), isNull);
    expect(priceChart(const [], now: DateTime.utc(2026, 10, 11)), isNull);
  });

  test('time runs from the first price to now', () {
    final chart = priceChart(
      [at(6, 6500), at(1, 7000)], // any order
      now: DateTime.utc(2026, 10, 11),
    )!;

    expect(chart.start, DateTime.utc(2026, 10, 1));
    expect(chart.end, DateTime.utc(2026, 10, 11));
    expect([for (final p in chart.changes) p.x], [0, 0.5]);
    expect([for (final p in chart.points) p.price], [7000, 6500]);
    expect(chart.changes[0].y, greaterThan(chart.changes[1].y));
  });

  test('prices stay inside the chart, with round prices on the axis', () {
    final chart = priceChart([
      at(1, 7000),
      at(3, 6800),
      at(5, 6500),
    ], now: DateTime.utc(2026, 10, 9))!;

    for (final p in chart.changes) {
      expect(p.y, inExclusiveRange(0, 1));
    }
    expect([for (final t in chart.ticks) t.price], [6500, 6750, 7000]);
    expect(chart.ticks.first.y, chart.changes.last.y);
    expect(chart.ticks.last.y, chart.changes.first.y);
    expect(chart.reference, isNull);
  });

  test("the site's earlier price is drawn above ours", () {
    final chart = priceChart(
      [at(1, 7000), at(5, 6500)],
      now: DateTime.utc(2026, 10, 9),
      siteBefore: 7500,
    )!;

    expect(chart.reference, 7500);
    expect(chart.referenceY, greaterThan(chart.changes.first.y));
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
    expect(chart.end, start.add(const Duration(days: 1)));
  });

  test('a flat history still has room above and below', () {
    final chart = priceChart([
      at(1, 7000),
      at(5, 7000),
    ], now: DateTime.utc(2026, 10, 9))!;

    expect(chart.changes.first.y, inExclusiveRange(0, 1));
    expect([for (final t in chart.ticks) t.price], [6980, 7000, 7020]);
  });

  test('a placeholder price is left out of the chart', () {
    // The CB650R that went 8 500 → 8 000 → "8 €" → 7 700.
    final chart = priceChart([
      at(13, 8500),
      at(18, 8000),
      at(23, 8),
      at(24, 7700),
    ], now: DateTime.utc(2026, 10, 28))!;

    expect([for (final p in chart.points) p.price], [8500, 8000, 7700]);
    expect(chart.changes, hasLength(3));
    expect(chart.moves, [PriceMove.first, PriceMove.drop, PriceMove.drop]);
    // Only one real price besides placeholders: nothing to draw.
    expect(
      priceChart([at(1, 7000), at(3, 1)], now: DateTime.utc(2026, 10, 9)),
      isNull,
    );
  });

  test('each dot knows how its price moved', () {
    final chart = priceChart([
      at(1, 7000),
      at(3, 7200),
      at(5, 7200),
      at(7, 6900),
    ], now: DateTime.utc(2026, 10, 9))!;

    expect(chart.moves, [
      PriceMove.first,
      PriceMove.rise,
      PriceMove.same,
      PriceMove.drop,
    ]);
  });

  group('priceTicks', () {
    test('round steps of 1, 2, 2.5 or 5 times a power of ten', () {
      expect(priceTicks(6425, 7075), [6500, 6750, 7000]);
      expect(priceTicks(9000, 12000), [9000, 10000, 11000, 12000]);
      expect(priceTicks(4100, 4700), [4200, 4400, 4600]);
    });

    test('never closer than 10 €', () {
      expect(priceTicks(1994, 2006), [2000]);
    });

    test('nothing for an empty range', () {
      expect(priceTicks(7000, 7000), isEmpty);
    });
  });

  test('a tap picks the nearest price, the newer of two at once', () {
    final chart = priceChart([
      at(1, 7000),
      at(5, 6800),
      at(5, 6700),
      at(9, 6500),
    ], now: DateTime.utc(2026, 10, 11))!;

    expect(nearestChange(chart, 0), 0);
    expect(nearestChange(chart, 0.15), 0);
    expect(nearestChange(chart, 0.45), 2);
    expect(nearestChange(chart, 1), 3);
  });
}
