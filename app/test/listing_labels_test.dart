import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/core/localization/app_language.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/listing_labels.dart';

Listing _listing(double? price) => Listing(
  id: 'l1',
  source: 'olx',
  url: 'https://www.olx.pt/d/anuncio/x.html',
  brand: 'Yamaha',
  model: 'MT-07',
  status: ListingStatus.active,
  sellerType: SellerType.private,
  images: const [],
  price: price,
);

void main() {
  test('sources are shown by the names people know', () {
    expect(sourceLabel('standvirtual'), 'Standvirtual');
    expect(sourceLabel('olx'), 'OLX');
    expect(sourceLabel('something-new'), 'something-new');
  });

  group('a price under 300 € is a placeholder', () {
    test('it has no asking price, as the database says', () {
      expect(_listing(1).askingPrice, isNull);
      expect(_listing(299.99).askingPrice, isNull);
      expect(_listing(300).askingPrice, 300);
      expect(_listing(6500).askingPrice, 6500);
      expect(_listing(null).askingPrice, isNull);
    });

    test('only a price that is there can be a placeholder', () {
      expect(_listing(1).hasPlaceholderPrice, isTrue);
      expect(_listing(300).hasPlaceholderPrice, isFalse);
      expect(_listing(null).hasPlaceholderPrice, isFalse);
    });

    test('it reads "price on request", never "1 €"', () {
      expect(_listing(1).priceLabel(), 'Preço por consultar');
      expect(
        _listing(1).priceLabel(language: AppLanguage.english),
        'Price on request',
      );
      expect(_listing(300).priceLabel(), Formatters.price(300));
      expect(
        _listing(6500).priceLabel(language: AppLanguage.english),
        Formatters.price(6500, language: AppLanguage.english),
      );
      expect(_listing(null).priceLabel(), Formatters.price(null));
    });
  });
}
