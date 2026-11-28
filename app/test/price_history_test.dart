import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/price_point.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/price_history.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/price_history_text.dart';

PricePoint at(int day, double price) =>
    PricePoint(price: price, observedAt: DateTime.utc(2026, 11, day));

void main() {
  // The CB650R of the screenshot, newest first as the database sent it.
  final history = [at(24, 7700), at(23, 8), at(18, 8000), at(13, 8500)];

  test('rows run newest first, each against the real price before it', () {
    final rows = priceHistoryRows(history);

    expect(
      [for (final row in rows) row.point.observedAt.day],
      [24, 23, 18, 13],
    );
    expect(
      [for (final row in rows) row.move],
      [PriceMove.drop, PriceMove.placeholder, PriceMove.drop, PriceMove.first],
    );
    // 7 700 is 300 € under 8 000, never 7 692 € over "8 €".
    expect(rows[0].change, -300);
    expect(rows[0].changePct, closeTo(-3.75, 1e-9));
    expect(rows[1].change, isNull);
    expect(rows[2].change, -500);
    expect(rows[3].change, isNull);
  });

  test('a price back where it was before a placeholder did not move', () {
    final rows = priceHistoryRows([at(1, 7000), at(2, 1), at(3, 7000)]);

    expect(rows.first.move, PriceMove.same);
    expect(rows.first.change, 0);
    expect(priceRowMoveText(rows.first), isNull);
  });

  test('a history that starts with a placeholder starts at the real price', () {
    final rows = priceHistoryRows([at(1, 1), at(2, 7000), at(3, 6800)]);

    expect(
      [for (final row in rows) row.move],
      [PriceMove.drop, PriceMove.first, PriceMove.placeholder],
    );
  });

  test('the summary has the first, lowest and overall change', () {
    final summary = priceHistorySummary(history)!;

    expect(summary.first, 8500);
    expect(summary.firstAt, DateTime.utc(2026, 11, 13));
    expect(summary.lowest, 7700);
    expect(summary.lowestAt, DateTime.utc(2026, 11, 24));
    expect(summary.latest, 7700);
    expect(summary.change, -800);
    expect(summary.changePct, closeTo(-9.41, 0.01));
    expect(summary.changes, 2);
  });

  test('the lowest is dated the last time it was asked', () {
    final summary = priceHistorySummary([
      at(1, 7000),
      at(3, 6500),
      at(5, 6900),
      at(7, 6500),
    ])!;

    expect(summary.lowestAt, DateTime.utc(2026, 11, 7));
    expect(summary.change, -500);
    expect(summary.changes, 3);
  });

  test('no summary without two real prices', () {
    expect(priceHistorySummary([at(1, 7000)]), isNull);
    expect(priceHistorySummary([at(1, 7000), at(2, 8)]), isNull);
    expect(priceHistorySummary(const []), isNull);
  });

  test('moves read with their arrow, euros and sign', () {
    String euros(double value) => Formatters.price(value);
    expect(priceMoveText(-800, -9.41), '↓ ${euros(800)} · −9,4 %');
    expect(priceMoveText(500, 6.25), '↑ ${euros(500)} · +6,3 %');
    expect(priceMoveText(0, 0), euros(0));
    expect(
      priceMoveText(-800, -9.41, language: AppLanguage.english),
      '↓ €800 · −9.4%',
    );
    final rows = priceHistoryRows(history);
    expect(priceRowMoveText(rows[0]), '↓ ${euros(300)} · −3,8 %');
    expect(priceRowMoveText(rows[1]), isNull);
    expect(priceRowMoveText(rows[3]), isNull);
  });

  test('the move splits into the euros and the share for the tile', () {
    expect(priceMoveParts(-800, -9.41), (
      '↓ ${Formatters.price(800)}',
      '−9,4 %',
    ));
    expect(priceMoveParts(0, 0), (Formatters.price(0), null));
  });
}
