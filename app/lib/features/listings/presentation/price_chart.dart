import 'dart:math';

import '../domain/entities/price_point.dart';
import 'price_history.dart';

/// A point in the chart, both coordinates from 0 to 1: x from the first
/// price to now, y from the bottom to the top.
typedef ChartPoint = ({double x, double y});

/// A gridline of the price axis: a round price and its height.
typedef PriceTick = ({double price, double y});

/// What the price chart draws, worked out without Flutter so it can be
/// tested. The painter only scales it to its size.
class const PriceChart({
  /// One dot per recorded real price, oldest first, and how it moved
  /// against the one before (N.128). Each price holds until the next
  /// one, the last until now ([end]), and its stretch of the line takes
  /// its move's colour (N.129: drops green, rises red).
  required final List<ChartPoint> changes,
  required final List<PriceMove> moves,

  /// The prices behind [changes], for the tap's label.
  required final List<PricePoint> points,

  /// Round prices for the axis on the left (N.129), lowest first.
  required final List<PriceTick> ticks,

  /// When the first price was seen (the left edge) and now (the right).
  required final DateTime start,
  required final DateTime end,

  /// The site's earlier price, from before we tracked the listing (dashed).
  final double? reference,
  final double? referenceY,
});

/// Null with fewer than two real prices: there is no change to draw.
/// Placeholders ("8 €", [isRealPrice]) are left out: one would flatten
/// every real change against the bottom (N.128).
PriceChart? priceChart(
  List<PricePoint> points, {
  required DateTime now,
  double? siteBefore,
}) {
  final sorted = byTime(points).where(isRealPrice).toList();
  if (sorted.length < 2) return null;

  final start = sorted.first.observedAt;
  var end = now.isAfter(sorted.last.observedAt) ? now : sorted.last.observedAt;
  // A history of minutes would squeeze every step into a line.
  if (end.difference(start) < const Duration(days: 1)) {
    end = start.add(const Duration(days: 1));
  }
  final span = end.difference(start).inSeconds;
  double x(DateTime t) => t.difference(start).inSeconds / span;

  final prices = [for (final p in sorted) p.price];
  final highest = prices.reduce(max);
  final lowest = prices.reduce(min);
  final reference = siteBefore != null && siteBefore > highest
      ? siteBefore
      : null;

  // Room above and below, so the line never sits on the edge; a flat
  // history gets a band of 2 % of its price.
  final ceiling = reference ?? highest;
  final range = max(ceiling - lowest, ceiling * 0.02);
  final top = ceiling + range * 0.15;
  final bottom = lowest - range * 0.15;
  double y(double price) => (price - bottom) / (top - bottom);

  return PriceChart(
    changes: [for (final p in sorted) (x: x(p.observedAt), y: y(p.price))],
    moves: [
      PriceMove.first,
      for (var i = 1; i < sorted.length; i++)
        sorted[i].price < sorted[i - 1].price
            ? PriceMove.drop
            : sorted[i].price > sorted[i - 1].price
            ? PriceMove.rise
            : PriceMove.same,
    ],
    points: sorted,
    ticks: [for (final t in priceTicks(bottom, top)) (price: t, y: y(t))],
    start: start,
    end: end,
    reference: reference,
    referenceY: reference == null ? null : y(reference),
  );
}

/// Round prices between [bottom] and [top] for the axis, about [target]
/// apart steps of 1, 2, 2.5 or 5 times a power of ten, never under 10 €
/// (N.129): 6 425-7 075 € gives 6 500, 6 750 and 7 000 €.
List<double> priceTicks(double bottom, double top, {int target = 3}) {
  final raw = (top - bottom) / target;
  if (raw <= 0) return const [];
  final magnitude = pow(10, (log(raw) / ln10).floor()).toDouble();
  final step = max(
    10.0,
    const [
      1.0,
      2.0,
      2.5,
      5.0,
      10.0,
    ].map((m) => m * magnitude).firstWhere((s) => s >= raw - 1e-9),
  );
  return [for (var k = (bottom / step).ceil(); k * step <= top; k++) k * step];
}

/// The recorded price nearest to [x] (0 to 1 across the chart), for the
/// label a tap or the mouse shows (N.129); of two at the same time, the
/// newer.
int nearestChange(PriceChart chart, double x) {
  var best = 0;
  for (var i = 1; i < chart.changes.length; i++) {
    if ((chart.changes[i].x - x).abs() <= (chart.changes[best].x - x).abs()) {
      best = i;
    }
  }
  return best;
}
