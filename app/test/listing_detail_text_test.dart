import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/listing_detail_text.dart';

Listing listing({int? year, int? mileage, String? location}) => Listing(
  id: 'l1',
  source: 'olx',
  url: 'https://www.olx.pt/d/anuncio/x.html',
  brand: 'Yamaha',
  model: 'MT-07',
  status: ListingStatus.active,
  sellerType: SellerType.private,
  images: const [],
  year: year,
  mileage: mileage,
  location: location,
);

void main() {
  test('the key facts read in one line', () {
    expect(
      keyFactsLine(listing(year: 2022, mileage: 12300, location: 'Lisboa')),
      matches(RegExp(r'^2022 · 12.300 km · Lisboa · Particular$')),
    );
  });

  test('missing facts are left out', () {
    expect(keyFactsLine(listing(location: '  ')), 'Particular');
  });

  test('the photo counter starts at one', () {
    expect(photoCounterText(0, 12), '1 / 12');
    expect(photoCounterText(11, 12), '12 / 12');
  });

  test('the ad button names the site', () {
    expect(originalLinkLabel('olx'), 'Ver no OLX');
    expect(originalLinkLabel('standvirtual'), 'Ver no Standvirtual');
    expect(originalLinkLabel('manual'), 'Ver anúncio original');
    expect(originalLinkLabel('facebook'), 'Ver no Facebook');
    expect(originalLinkLabel('custojusto'), 'Ver no CustoJusto');
    expect(originalLinkLabel('other'), 'Ver anúncio original');
  });
}
