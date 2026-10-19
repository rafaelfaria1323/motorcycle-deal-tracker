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
  });

  test('the bike: year and km always, the rest only when known', () {
    expect(bikeFacts(listing()), [('Ano', '—'), ('Quilometragem', '—')]);

    const full = Listing(
      id: 'l2',
      source: 'standvirtual',
      url: 'https://www.standvirtual.com/motos/anuncio/x.html',
      brand: 'Honda',
      model: 'CB650R',
      status: ListingStatus.active,
      sellerType: SellerType.dealer,
      images: [],
      year: 2023,
      registrations: 1,
      serviceBook: false,
      origin: 'imported',
      dealerWarrantyMonths: 18,
    );
    expect(bikeFacts(full).map((f) => f.$1), [
      'Ano',
      'Quilometragem',
      'Registos (donos)',
      'Livro de revisões',
      'Origem',
      'Garantia do vendedor',
    ]);
    expect(bikeFacts(full), contains(('Livro de revisões', 'Não')));
    expect(bikeFacts(full), contains(('Origem', 'Importada')));
    expect(bikeFacts(full), contains(('Garantia do vendedor', '18 meses')));
  });

  test('the ad: dashes for the unknown, dates only when known', () {
    final facts = adFacts(listing());

    expect(facts.map((f) => f.$1), [
      'Localização',
      'Vendedor',
      'Tipo de vendedor',
      'Fonte',
      'Estado',
    ]);
    expect(facts.first, ('Localização', '—'));
    expect(facts, contains(('Fonte', 'OLX')));

    final published = Listing(
      id: 'l3',
      source: 'olx',
      url: 'https://www.olx.pt/d/anuncio/y.html',
      brand: 'Yamaha',
      model: 'MT-07',
      status: ListingStatus.active,
      sellerType: SellerType.private,
      images: const [],
      publishedAt: DateTime(2026, 10, 9),
    );
    expect(
      adFacts(published, now: DateTime(2026, 10, 19)),
      contains(('Publicado', '09/10/2026 (há 10 dias)')),
    );
  });
}
