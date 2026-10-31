import 'package:equatable/equatable.dart';

/// A model in the catalog, tracked or not.
class const CatalogModel({
  required final String id,
  required final String brand,
  required final String model,

  /// The account's own first year (the catalog's when it never chose one).
  required final int minYear,

  /// Followed by this account: its listings are in Ofertas, the alerts and
  /// the market figures.
  required final bool isTracked,

  /// Followed by some account (this one or another): the collector runs
  /// its searches, matches and scores its listings.
  final bool isCollected = false,

  /// The account's favourite colours for this model (codes, as
  /// `listings.colour`): a plus and a filter, never Deal Score points.
  final List<String> colours = const [],

  /// The search address that lists the model on each site, if any.
  final String? olxSearch,
  final String? standvirtualSearch,

  /// Official new-bike list price, and when it was checked; null when not
  /// set.
  final double? newPrice,
  final DateTime? newPriceCheckedAt,
}) extends Equatable {
  CatalogModel copyWith({
    bool? isTracked,
    int? minYear,
    List<String>? colours,
  }) => CatalogModel(
    id: id,
    brand: brand,
    model: model,
    minYear: minYear ?? this.minYear,
    isTracked: isTracked ?? this.isTracked,
    isCollected: isCollected,
    colours: colours ?? this.colours,
    olxSearch: olxSearch,
    standvirtualSearch: standvirtualSearch,
    newPrice: newPrice,
    newPriceCheckedAt: newPriceCheckedAt,
  );

  /// The same model with another new-bike price (null clears it).
  CatalogModel withNewPrice(double? price, DateTime checkedAt) => CatalogModel(
    id: id,
    brand: brand,
    model: model,
    minYear: minYear,
    isTracked: isTracked,
    isCollected: isCollected,
    colours: colours,
    olxSearch: olxSearch,
    standvirtualSearch: standvirtualSearch,
    newPrice: price,
    newPriceCheckedAt: price == null ? null : checkedAt,
  );

  @override
  List<Object?> get props => [
    id,
    brand,
    model,
    minYear,
    isTracked,
    isCollected,
    colours,
    olxSearch,
    standvirtualSearch,
    newPrice,
    newPriceCheckedAt,
  ];
}

/// The models grouped by brand, brands and models in alphabetical order.
Map<String, List<CatalogModel>> modelsByBrand(List<CatalogModel> models) {
  final sorted = [...models]
    ..sort((a, b) {
      final brand = a.brand.compareTo(b.brand);
      return brand != 0 ? brand : a.model.compareTo(b.model);
    });
  final byBrand = <String, List<CatalogModel>>{};
  for (final m in sorted) {
    byBrand.putIfAbsent(m.brand, () => []).add(m);
  }
  return byBrand;
}
