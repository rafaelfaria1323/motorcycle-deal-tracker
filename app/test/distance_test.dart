import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/models/listing_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/models/saved_search_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_filters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_sort.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/saved_search.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/listing_detail_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/listing_labels.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/saved_search_summary.dart';
import 'package:motorcycle_deal_tracker/features/settings/domain/place.dart';
import 'package:motorcycle_deal_tracker/features/settings/presentation/place_text.dart';

Listing _listing({String? location, int? distanceKm}) => Listing(
  id: 'l1',
  source: 'olx',
  url: 'https://www.olx.pt/d/anuncio/x.html',
  brand: 'Yamaha',
  model: 'MT-07',
  status: ListingStatus.active,
  sellerType: SellerType.private,
  images: const [],
  year: 2022,
  location: location,
  distanceKm: distanceKm,
);

void main() {
  group('placeKey (same as the database place_key)', () {
    test('lower case, no accents, no parish, nothing after a comma', () {
      expect(placeKey('Santarém (Marvila), Santa Iria da Ribeira'), 'santarem');
      expect(placeKey('  Vila Nova de Gaia '), 'vila nova de gaia');
      expect(placeKey('Póvoa-de-Varzim'), 'povoa de varzim');
      expect(placeKey('São João da Madeira'), 'sao joao da madeira');
      expect(placeKey('ÉVORA'), 'evora');
      expect(placeKey(''), '');
    });
  });

  test('uniquePlaces keeps one entry per name, the exact town first', () {
    expect(
      uniquePlaces(const [
        Place(key: 'porto de mos', name: 'Porto de Mós'),
        Place(key: 'porto', name: 'Porto'),
        Place(key: 'madeira', name: 'Funchal'),
        Place(key: 'funchal', name: 'Funchal'),
      ]),
      const [
        Place(key: 'porto', name: 'Porto'),
        Place(key: 'funchal', name: 'Funchal'),
        Place(key: 'porto de mos', name: 'Porto de Mós'),
      ],
    );
  });

  group('listing place', () {
    test('with and without a distance', () {
      expect(
        placeText(_listing(location: 'Matosinhos', distanceKm: 8)),
        'Matosinhos, a ${Formatters.mileage(8)}',
      );
      expect(placeText(_listing(location: ' Lisboa ')), 'Lisboa');
      expect(placeText(_listing(location: '  ', distanceKm: 8)), isNull);
      expect(placeText(_listing(distanceKm: 8)), isNull);
    });

    test('in the key facts line', () {
      expect(
        keyFactsLine(_listing(location: 'Porto', distanceKm: 274)),
        '2022 · Porto, a ${Formatters.mileage(274)} · Particular',
      );
    });

    test('read from the computed field', () {
      final row = {
        'id': 'l1',
        'source': 'olx',
        'url': 'https://example.com/x',
        'brand': 'Honda',
        'model': 'CB650R',
        'status': 'active',
        'first_seen_at': '2026-10-18T19:00:00Z',
        'last_seen_at': '2026-10-19T08:00:00Z',
      };
      expect(ListingModel.fromJson({...row, 'distance_km': 42}).distanceKm, 42);
      expect(ListingModel.fromJson(row).distanceKm, isNull);
      expect(ListingModel.summaryColumns, contains('distance_km'));
    });
  });

  group('distance filter', () {
    test('counts as a filter and a saved-search criterion', () {
      const filters = ListingFilters(maxDistanceKm: 50);
      expect(filters.appliedCount, 1);
      expect(filters.hasCriteria, isTrue);
      expect(filters.criteriaOnly.maxDistanceKm, 50);
    });

    test('summary and chip', () {
      const filters = ListingFilters(maxPrice: 7000, maxDistanceKm: 50);
      expect(
        summarizeFilters(filters, const []),
        'até ${Formatters.price(7000)} · até ${Formatters.mileage(50)} de casa',
      );
      final chip = filterChips(filters, const []).last;
      expect(chip.label, 'até ${Formatters.mileage(50)} de casa');
      expect(chip.without, const ListingFilters(maxPrice: 7000));
    });

    test('saved with the search and read back', () {
      expect(
        SavedSearchModel.toInsert(
          'Perto',
          const ListingFilters(maxDistanceKm: 100),
        )['max_distance_km'],
        100,
      );
      expect(
        SavedSearchModel.fromJson({
          'id': 's1',
          'created_at': '2026-10-19T08:00:00Z',
          'max_distance_km': 100,
        }).filters.maxDistanceKm,
        100,
      );
    });

    test('nearest first is a sort order', () {
      expect(ListingSort.nearest.label(), 'Mais perto');
    });
  });
}
