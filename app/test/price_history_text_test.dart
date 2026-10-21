import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/price_history_text.dart';

Listing listing({double? initial, double? before, double? price}) => Listing(
  id: '1',
  source: 'standvirtual',
  url: 'https://example.com',
  brand: 'Yamaha',
  model: 'MT-07',
  status: ListingStatus.active,
  sellerType: SellerType.dealer,
  images: const [],
  initialPrice: initial,
  priceBeforeDrop: before,
  price: price,
);

void main() {
  test('a cut from before tracking counts as a price change', () {
    final l = listing(initial: 6500, before: 6800, price: 6500);

    expect(l.referencePrice, 6800);
    expect(l.priceChange, -300);
    expect(l.hasPriceChanged, isTrue);
    expect(siteDropLine(l), contains('Standvirtual'));
    expect(siteDropLine(l), contains('4,4 %'));
  });

  test('our own first price wins when it is higher', () {
    final l = listing(initial: 7000, before: 6800, price: 6500);

    expect(l.referencePrice, 7000);
    expect(l.priceChange, -500);
    expect(siteDropLine(l), isNull);
  });

  test('without a site note nothing changes', () {
    final l = listing(initial: 6500, price: 6500);

    expect(l.referencePrice, 6500);
    expect(l.hasPriceChanged, isFalse);
    expect(siteDropLine(l), isNull);
  });

  test('a price raised back above the earlier one shows no cut line', () {
    final l = listing(initial: 6500, before: 6800, price: 6900);

    expect(siteDropLine(l), isNull);
  });

  test('the seen line: first seen, then last seen', () {
    const base = Listing(
      id: '2',
      source: 'olx',
      url: 'https://example.com/2',
      brand: 'Yamaha',
      model: 'R7',
      status: ListingStatus.active,
      sellerType: SellerType.private,
      images: [],
    );
    expect(seenLine(base), isNull);

    final seen = Listing(
      id: '3',
      source: 'olx',
      url: 'https://example.com/3',
      brand: 'Yamaha',
      model: 'R7',
      status: ListingStatus.active,
      sellerType: SellerType.private,
      images: const [],
      firstSeenAt: DateTime(2026, 10, 3, 12),
      lastSeenAt: DateTime(2026, 10, 17, 12),
    );
    expect(
      seenLine(seen, now: DateTime(2026, 10, 19, 12)),
      'Visto pela primeira vez em 03/10/2026 · última vez há 2 dias',
    );
  });
}
