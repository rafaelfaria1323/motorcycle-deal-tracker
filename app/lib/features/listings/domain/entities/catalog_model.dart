import 'package:equatable/equatable.dart';

/// A model in the catalog, tracked or not.
class CatalogModel extends Equatable {
  const CatalogModel({
    required this.id,
    required this.brand,
    required this.model,
    required this.minYear,
    required this.isTracked,
  });

  final String id;
  final String brand;
  final String model;
  final int minYear;

  /// The collector matches, scores and alerts only on tracked models.
  final bool isTracked;

  CatalogModel withTracked(bool tracked) => CatalogModel(
    id: id,
    brand: brand,
    model: model,
    minYear: minYear,
    isTracked: tracked,
  );

  @override
  List<Object?> get props => [id, brand, model, minYear, isTracked];
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
