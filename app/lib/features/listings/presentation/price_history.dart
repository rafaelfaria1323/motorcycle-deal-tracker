import 'dart:math';

import '../domain/entities/listing.dart' show minRealPrice;
import '../domain/entities/price_point.dart';

/// How a recorded price moved from the real price before it (N.128).
enum PriceMove {
  /// The first real price seen.
  first,
  drop,
  rise,

  /// Back at the price before a placeholder.
  same,

  /// "1 €", "consultar": no price ([minRealPrice]), never compared.
  placeholder,
}

/// The recorded prices oldest first, whatever order they came in.
List<PricePoint> byTime(List<PricePoint> points) =>
    [...points]..sort((a, b) => a.observedAt.compareTo(b.observedAt));

/// Whether [point] is a real asking price, not a placeholder.
bool isRealPrice(PricePoint point) => point.price >= minRealPrice;

/// A row of the price history: the price, and how far it moved from the
/// real price before it ([change] in euros, [changePct] in % of that
/// price; null for the first price and a placeholder).
class const PriceHistoryRow({
  required final PricePoint point,
  required final PriceMove move,
  final double? change,
  final double? changePct,
});

/// The recorded prices newest first, each against the real price before
/// it: a placeholder in between ("8 €") is listed but neither compared
/// nor compared with.
List<PriceHistoryRow> priceHistoryRows(List<PricePoint> points) {
  final rows = <PriceHistoryRow>[];
  double? before;
  for (final point in byTime(points)) {
    if (!isRealPrice(point)) {
      rows.add(PriceHistoryRow(point: point, move: .placeholder));
      continue;
    }
    final previous = before;
    before = point.price;
    if (previous == null) {
      rows.add(PriceHistoryRow(point: point, move: .first));
      continue;
    }
    final change = point.price - previous;
    rows.add(
      PriceHistoryRow(
        point: point,
        move: change < 0
            ? .drop
            : change > 0
            ? .rise
            : .same,
        change: change,
        changePct: change / previous * 100,
      ),
    );
  }
  return rows.reversed.toList();
}

/// The history in three figures: the first real price, the lowest and
/// the change from the first to the latest, over [changes] drops and
/// rises.
class const PriceHistorySummary({
  required final double first,
  required final DateTime firstAt,
  required final double lowest,
  required final DateTime lowestAt,
  required final double latest,
  required final int changes,
}) {
  double get change => latest - first;
  double get changePct => change / first * 100;
}

/// Null with fewer than two real prices: nothing has moved.
PriceHistorySummary? priceHistorySummary(List<PricePoint> points) {
  final real = byTime(points).where(isRealPrice).toList();
  if (real.length < 2) return null;
  // The latest time it was at its lowest.
  final lowest = real.reduce((a, b) => b.price <= a.price ? b : a);
  return PriceHistorySummary(
    first: real.first.price,
    firstAt: real.first.observedAt,
    lowest: real.map((p) => p.price).reduce(min),
    lowestAt: lowest.observedAt,
    latest: real.last.price,
    changes: [
      for (var i = 1; i < real.length; i++)
        if (real[i].price != real[i - 1].price) i,
    ].length,
  );
}
