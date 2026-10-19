import 'dart:math';

import '../domain/entities/price_point.dart';

/// A point in the chart, both coordinates from 0 to 1: x from the first
/// price to now, y from the bottom to the top.
typedef ChartPoint = ({double x, double y});

/// What the price chart draws, worked out without Flutter so it can be
/// tested. The painter only scales it to its size.
class PriceChart {
  const PriceChart({
    required this.line,
    required this.changes,
    required this.highest,
    required this.lowest,
    required this.highestY,
    required this.lowestY,
    required this.start,
    this.reference,
    this.referenceY,
  });

  /// The step line: each price holds until the next one, the last until now.
  final List<ChartPoint> line;

  /// One dot per recorded price.
  final List<ChartPoint> changes;

  /// Our highest and lowest recorded prices, labelled on the chart.
  final double highest;
  final double lowest;
  final double highestY;
  final double lowestY;

  /// When the first price was seen (the left edge).
  final DateTime start;

  /// The site's earlier price, from before we tracked the listing (dashed).
  final double? reference;
  final double? referenceY;
}

/// Null with fewer than two prices: there is no change to draw.
PriceChart? priceChart(
  List<PricePoint> points, {
  required DateTime now,
  double? siteBefore,
}) {
  if (points.length < 2) return null;
  final sorted = [...points]
    ..sort((a, b) => a.observedAt.compareTo(b.observedAt));

  final start = sorted.first.observedAt;
  var end = now.isAfter(sorted.last.observedAt) ? now : sorted.last.observedAt;
  // A history of minutes would squeeze every step into a line.
  if (end.difference(start) < const Duration(days: 1)) {
    end = start.add(const Duration(days: 1));
  }
  final span = end.difference(start).inSeconds;
  double x(DateTime t) => t.difference(start).inSeconds / span;

  final prices = [for (final p in sorted) p.price];
  final reference = siteBefore != null && siteBefore > prices.reduce(max)
      ? siteBefore
      : null;
  final highest = prices.reduce(max);
  final lowest = prices.reduce(min);

  // Room above and below, so the line never sits on the edge; a flat
  // history gets a band of 2 % of its price.
  final ceiling = reference ?? highest;
  final range = max(ceiling - lowest, ceiling * 0.02);
  final top = ceiling + range * 0.15;
  final bottom = lowest - range * 0.15;
  double y(double price) => (price - bottom) / (top - bottom);

  final line = <ChartPoint>[(x: 0, y: y(sorted.first.price))];
  for (var i = 1; i < sorted.length; i++) {
    final at = x(sorted[i].observedAt);
    line
      ..add((x: at, y: y(sorted[i - 1].price)))
      ..add((x: at, y: y(sorted[i].price)));
  }
  line.add((x: 1, y: y(sorted.last.price)));

  return PriceChart(
    line: line,
    changes: [for (final p in sorted) (x: x(p.observedAt), y: y(p.price))],
    highest: highest,
    lowest: lowest,
    highestY: y(highest),
    lowestY: y(lowest),
    start: start,
    reference: reference,
    referenceY: reference == null ? null : y(reference),
  );
}
