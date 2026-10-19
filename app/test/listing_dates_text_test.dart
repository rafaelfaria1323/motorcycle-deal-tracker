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
}
