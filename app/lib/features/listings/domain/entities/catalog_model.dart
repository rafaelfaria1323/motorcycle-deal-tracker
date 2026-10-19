import 'package:equatable/equatable.dart';

/// A model in the catalog, tracked or not.
class CatalogModel extends Equatable {
  const CatalogModel({
    required this.id,
    required this.brand,
    required this.model,
    required this.minYear,
    required this.isTracked,
    this.olxSearch,
    this.standvirtualSearch,
    this.newPrice,
    this.newPriceCheckedAt,
  });

  final String id;
  final String brand;
  final String model;
  final int minYear;

  /// The collector matches, scores and alerts only on tracked models, and
  /// runs only their searches.
  final bool isTracked;

  /// The search address that lists the model on each site, if any.
  final String? olxSearch;
  final String? standvirtualSearch;

  /// Official new-bike list price, and when it was checked; null when not
  /// set.
  final double? newPrice;
  final DateTime? newPriceCheckedAt;

  CatalogModel copyWith({bool? isTracked, int? minYear}) => CatalogModel(
    id: id,
    brand: brand,
    model: model,
    minYear: minYear ?? this.minYear,
    isTracked: isTracked ?? this.isTracked,
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
