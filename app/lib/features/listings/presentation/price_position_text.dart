import '../../../core/formatting/formatters.dart';
import 'market_behaviour_text.dart';

/// Where a listing's asking price sits among the other live listings of
/// its model, worked out without Flutter so it can be tested.
class PricePosition {
  const PricePosition({
    required this.cheaper,
    required this.same,
    required this.dearer,
    required this.median,
    required this.lowest,
    required this.highest,
    required this.othersX,
    required this.thisX,
  });

  /// Other live listings below, at and above this listing's price.
  final int cheaper;
  final int same;
  final int dearer;

  /// Of the other listings' prices.
  final double median;

  /// Ends of the strip: all prices, this listing's included.
  final double lowest;
  final double highest;

  /// Positions on the strip, from 0 (lowest) to 1 (highest).
  final List<double> othersX;
  final double thisX;

  int get others => cheaper + same + dearer;
}

/// Null when the listing has no price or there are fewer than
/// [minMarketData] other prices to compare with.
PricePosition? pricePosition(double? price, List<double> others) {
  if (price == null || others.length < minMarketData) return null;

  final sorted = [...others]..sort();
  final mid = sorted.length ~/ 2;
  final median = sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
  final lowest = price < sorted.first ? price : sorted.first;
  final highest = price > sorted.last ? price : sorted.last;
  final span = highest - lowest;
  double x(double p) => span == 0 ? 0.5 : (p - lowest) / span;

  return PricePosition(
    cheaper: sorted.where((p) => p < price).length,
    same: sorted.where((p) => p == price).length,
    dearer: sorted.where((p) => p > price).length,
    median: median,
    lowest: lowest,
    highest: highest,
    othersX: [for (final p in sorted) x(p)],
    thisX: x(price),
  );
}

/// The line for "Mercado deste modelo"; null when the listing has no price.
String? pricePositionLine(double? price, List<double> others) {
  if (price == null) return null;
  final position = pricePosition(price, others);
  if (position == null) {
    return 'Preço face aos outros anúncios: ainda poucos dados '
        '(${others.length} ${others.length == 1 ? 'anúncio ativo' : 'anúncios ativos'})';
  }

  final p = position;
  final all = p.others + 1;
  final median = 'mediana ${Formatters.price(p.median)}';
  if (p.same == 0 && p.cheaper == 0) {
    return 'O preço mais baixo dos $all anúncios ativos deste modelo '
        '($median)';
  }
  if (p.same == 0 && p.dearer == 0) {
    return 'O preço mais alto dos $all anúncios ativos deste modelo '
        '($median)';
  }

  final cheaper = switch (p.cheaper) {
    0 => 'Nenhum anúncio ativo é mais barato',
    1 => '1 anúncio ativo é mais barato',
    _ => '${p.cheaper} anúncios ativos são mais baratos',
  };
  final dearer = switch (p.dearer) {
    0 => 'nenhum é mais caro',
    1 => '1 é mais caro',
    _ => '${p.dearer} são mais caros',
  };
  final same = switch (p.same) {
    0 => '',
    1 => ', 1 tem o mesmo preço',
    _ => ', ${p.same} têm o mesmo preço',
  };
  return '$cheaper e $dearer$same ($median)';
}
