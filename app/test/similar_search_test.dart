import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/favourites/presentation/similar_search.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_filters.dart';

Listing listing({
  ListingStatus status = ListingStatus.removed,
  String? motorcycleId = 'cb650r',
  int? year = 2021,
  int? mileage = 12000,
  double? price = 6900,
}) => Listing(
  id: 'a',
  source: 'olx',
  url: 'https://www.olx.pt/d/anuncio/a.html',
  brand: 'Honda',
  model: 'CB650R',
  motorcycleId: motorcycleId,
  status: status,
  sellerType: SellerType.private,
  images: const [],
  price: price,
  year: year,
  mileage: mileage,
  firstSeenAt: DateTime.utc(2026, 10, 10),
);

void main() {
  test('a gone favourite: same model, a year either side, a little more', () {
    expect(
      similarSearchFilters(listing()),
      const ListingFilters(
        motorcycleIds: ['cb650r'],
        minYear: 2020,
        maxYear: 2022,
        // 6 900 € + 10 % = 7 590, up to 7 750.
        maxPrice: 7750,
        // 12 000 km + 30 % = 15 600, up to 16 000.
        maxMileage: 16000,
      ),
    );
  });

  test('a round figure stays round', () {
    // 2 500 € + 10 % is 2 750 exactly, not a step more.
    expect(similarSearchFilters(listing(price: 2500))!.maxPrice, 2750);
    expect(similarSearchFilters(listing(mileage: 10000))!.maxMileage, 13000);
  });

  test('low mileage still allows 3 000 km more', () {
    expect(similarSearchFilters(listing(mileage: 1500))!.maxMileage, 5000);
  });

  test('what the ad left out is not asked for', () {
    final filters = similarSearchFilters(
      listing(year: null, mileage: null, price: 1),
    )!;
    expect(filters.minYear, isNull);
    expect(filters.maxYear, isNull);
    // A placeholder price ("1 €") is no price.
    expect(filters.maxPrice, isNull);
    expect(filters.maxMileage, isNull);
    expect(filters.motorcycleIds, ['cb650r']);
  });

  test('nothing for a live ad or one outside the catalog', () {
    expect(similarSearchFilters(listing(status: ListingStatus.active)), isNull);
    expect(similarSearchFilters(listing(motorcycleId: null)), isNull);
  });

  test('the suggested name, in both languages', () {
    expect(similarSearchName(listing()), 'Parecida com Honda CB650R 2021');
    expect(
      similarSearchName(listing(year: null), language: AppLanguage.english),
      'Like Honda CB650R',
    );
  });
}
