import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/listing_dates_text.dart';

Listing listing({DateTime? published, DateTime? renewed}) => Listing(
  id: 'l1',
  source: 'olx',
  url: 'https://www.olx.pt/d/anuncio/x.html',
  brand: 'Yamaha',
  model: 'MT-07',
  status: ListingStatus.active,
  sellerType: SellerType.private,
  images: const [],
  publishedAt: published,
  siteRefreshedAt: renewed,
);

void main() {
  test('a date reads with its age', () {
    expect(
      dateWithAge(DateTime(2026, 5, 18), now: DateTime(2026, 10, 19)),
      '18/05/2026 (há 154 dias)',
    );
  });

  test('a renewal shows only when it came a day or more later', () {
    final published = DateTime(2026, 5, 18);

    expect(
      renewalToShow(
        listing(published: published, renewed: DateTime(2026, 10, 19)),
      ),
      DateTime(2026, 10, 19),
    );
    expect(
      renewalToShow(
        listing(published: published, renewed: DateTime(2026, 5, 18, 6)),
      ),
      isNull,
    );
    expect(renewalToShow(listing(published: published)), isNull);
  });

  group('relisted bikes', () {
    Listing relisted({String? from = 'old', double? before, double? price}) =>
        Listing(
          id: 'l2',
          source: 'olx',
          url: 'https://www.olx.pt/d/anuncio/y.html',
          brand: 'Yamaha',
          model: 'MT-07',
          status: ListingStatus.active,
          sellerType: SellerType.private,
          images: const [],
          price: price,
          relistedFrom: from,
          relistedSince: DateTime(2026, 7, 25),
          relistedPrice: before,
        );
    final now = DateTime(2026, 10, 19);

    test('the earlier ad, its date and how the price moved', () {
      expect(
        relistText(relisted(before: 6500, price: 6200), now: now),
        allOf(
          startsWith(
            'Esteve à venda noutro anúncio desde 25/07/2026 (há 86 dias), '
            'a última vez por ',
          ),
          contains('(agora menos '),
        ),
      );
      expect(
        relistText(relisted(before: 6200, price: 6500), now: now),
        contains('(agora mais '),
      );
      expect(
        relistText(relisted(before: 6500, price: 6500), now: now),
        isNot(contains('agora')),
      );
      expect(
        relistText(relisted(), now: now),
        'Esteve à venda noutro anúncio desde 25/07/2026 (há 86 dias).',
      );
    });

    test('nothing for a listing that is not a relist', () {
      expect(relistText(relisted(from: null), now: now), isNull);
    });
  });
}
