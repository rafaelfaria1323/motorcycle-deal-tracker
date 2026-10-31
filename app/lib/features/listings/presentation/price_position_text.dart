import '../../../core/formatting/formatters.dart';
import 'market_behaviour_text.dart';
import '../../../core/localization/localizations.dart';

/// Where a listing's asking price sits among the other live listings of
/// its model, worked out without Flutter so it can be tested.
class const PricePosition({
  /// Other live listings below, at and above this listing's price.
  required final int cheaper,
  required final int same,
  required final int dearer,

  /// Of the other listings' prices.
  required final double median,

  /// Ends of the strip: all prices, this listing's included.
  required final double lowest,
  required final double highest,

  /// Positions on the strip, from 0 (lowest) to 1 (highest).
  required final List<double> othersX,
  required final double thisX,
}) {
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
String? pricePositionLine(
  double? price,
  List<double> others, {
  AppLanguage language = .portuguese,
}) {
  if (price == null) return null;
  final position = pricePosition(price, others);
  if (position == null) {
    return language.messages.pricePositionFewData(count: others.length);
  }

  final p = position;
  final all = p.others + 1;
  final median = language.messages.median(
    price: Formatters.price(p.median, language: language),
  );
  if (p.same == 0 && p.cheaper == 0) {
    return language.messages.priceLowestAmongActive(
      all: (all).toString(),
      median: median,
    );
  }
  if (p.same == 0 && p.dearer == 0) {
    return language.messages.priceHighestAmongActive(
      all: (all).toString(),
      median: median,
    );
  }

  final cheaper = switch (p.cheaper) {
    0 => language.messages.noActiveListingIsCheaper,
    1 => language.messages.text1ActiveListingIsCheaper,
    _ => language.messages.activeListingsAreCheaper(
      cheaper: p.cheaper.toString(),
    ),
  };
  final dearer = switch (p.dearer) {
    0 => language.messages.noneIsMoreExpensive,
    1 => language.messages.text1IsMoreExpensive,
    _ => language.messages.areMoreExpensive(dearer: p.dearer.toString()),
  };
  final same = switch (p.same) {
    0 => '',
    1 => language.messages.text1HasSamePrice,
    _ => language.messages.haveSamePrice(same: p.same.toString()),
  };
  return language.messages.and(
    cheaper: cheaper,
    dearer: dearer,
    same: same,
    median: median,
  );
}
