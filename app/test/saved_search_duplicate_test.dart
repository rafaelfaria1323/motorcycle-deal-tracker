import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_filters.dart';
import 'package:motorcycle_deal_tracker/features/saved_searches/domain/entities/saved_search.dart';
import 'package:motorcycle_deal_tracker/features/saved_searches/presentation/saved_search_summary.dart';

SavedSearch search(String id, ListingFilters filters, {String? name}) =>
    SavedSearch(
      id: id,
      name: name,
      filters: filters,
      createdAt: DateTime(2026, 10, 23),
    );

void main() {
  const hondas = ListingFilters(
    motorcycleIds: ['cb', 'cbr'],
    maxPrice: 7500,
    extras: ['quickshifter', 'exhaust'],
  );

  test('a saved search applied in Ofertas is found', () {
    final saved = search('a', hondas);
    expect(savedSearchLike([saved], hondas), saved);
  });

  test('the order of models and extras and the live-only switch '
      'do not count', () {
    final saved = search('a', hondas);
    const reordered = ListingFilters(
      motorcycleIds: ['cbr', 'cb'],
      maxPrice: 7500,
      extras: ['exhaust', 'quickshifter'],
      activeOnly: false,
    );
    expect(savedSearchLike([saved], reordered), saved);
  });

  test('any other criterion makes it a different search', () {
    final saved = search('a', hondas);
    for (final other in const [
      ListingFilters(
        motorcycleIds: ['cb'],
        maxPrice: 7500,
        extras: ['quickshifter', 'exhaust'],
      ),
      ListingFilters(
        motorcycleIds: ['cb', 'cbr'],
        maxPrice: 8000,
        extras: ['quickshifter', 'exhaust'],
      ),
      ListingFilters(
        motorcycleIds: ['cb', 'cbr'],
        maxPrice: 7500,
        extras: ['quickshifter', 'exhaust'],
        sellerType: SellerType.private,
      ),
      ListingFilters(
        motorcycleIds: ['cb', 'cbr'],
        maxPrice: 7500,
        extras: ['quickshifter', 'exhaust'],
        onlyMyColours: true,
      ),
      ListingFilters.empty,
    ]) {
      expect(savedSearchLike([saved], other), isNull, reason: '$other');
    }
  });

  test('an edited search is not a repeat of itself', () {
    final saved = search('a', hondas);
    expect(savedSearchLike([saved], hondas, except: 'a'), isNull);
    final other = search('b', hondas);
    expect(savedSearchLike([saved, other], hondas, except: 'a'), other);
  });

  test('the message names the saved search', () {
    expect(
      alreadySavedText(search('a', hondas, name: 'Hondas baratas')),
      'Esta pesquisa já está guardada como "Hondas baratas".',
    );
    expect(
      alreadySavedText(search('a', hondas)),
      'Esta pesquisa já está guardada como "Pesquisa sem nome".',
    );
  });
}
