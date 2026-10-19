import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/catalog_model.dart';

CatalogModel model(String brand, String name, {bool tracked = false}) =>
    CatalogModel(
      id: '$brand-$name',
      brand: brand,
      model: name,
      minYear: 2023,
      isTracked: tracked,
    );

void main() {
  test('groups models by brand in alphabetical order', () {
    final grouped = modelsByBrand([
      model('Yamaha', 'Tracer 7'),
      model('Honda', 'CB650R', tracked: true),
      model('Yamaha', 'MT-07', tracked: true),
      model('Honda', 'CB125R'),
    ]);

    expect(grouped.keys, ['Honda', 'Yamaha']);
    expect(grouped['Honda']!.map((m) => m.model), ['CB125R', 'CB650R']);
    expect(grouped['Yamaha']!.map((m) => m.model), ['MT-07', 'Tracer 7']);
  });

  test('switching a model keeps everything else', () {
    final on = model('Yamaha', 'R9').copyWith(isTracked: true);

    expect(on.isTracked, isTrue);
    expect(on, model('Yamaha', 'R9', tracked: true));
  });
}
