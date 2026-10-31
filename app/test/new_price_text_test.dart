import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/new_price_text.dart';

Listing listing({double? price, double? newPrice, DateTime? checkedAt}) =>
    Listing(
      id: 'l1',
      source: 'olx',
      url: 'https://www.olx.pt/d/anuncio/x.html',
      brand: 'Yamaha',
      model: 'MT-07',
      status: ListingStatus.active,
      sellerType: SellerType.private,
      images: const [],
      price: price,
      newPrice: newPrice,
      newPriceCheckedAt: checkedAt,
    );

void main() {
  final checked = DateTime(2026, 10, 13);
  final now = DateTime(2026, 10, 19);

  test('nothing to compare without both prices', () {
    expect(newPriceLines(listing(price: 7000)), isEmpty);
    expect(newPriceLines(listing(newPrice: 8250)), isEmpty);
    expect(newPriceLines(listing(price: 7000, newPrice: 0)), isEmpty);
    expect(newPriceLines(listing(price: 7000, newPrice: -1)), isEmpty);
    // "1 €" is a placeholder, not 8 249 € below a new one.
    expect(newPriceLines(listing(price: 1, newPrice: 8250)), isEmpty);
  });

  test('shows how much cheaper than a new one', () {
    final lines = newPriceLines(
      listing(price: 7000, newPrice: 8250, checkedAt: checked),
      now: now,
    );

    expect(lines, [
      'Preço de uma nova: ${Formatters.price(8250)}',
      '${Formatters.price(1250)} abaixo de uma nova (15 %)',
      'Preço de uma nova verificado em 13/10/2026',
    ]);
  });

  test('a small discount suggests comparing with a new one', () {
    final lines = newPriceLines(listing(price: 7900, newPrice: 8250), now: now);

    expect(lines, contains(startsWith('Menos de 10 % abaixo de uma nova')));
  });

  test('a price above a new one is flagged', () {
    final lines = newPriceLines(listing(price: 9000, newPrice: 8250), now: now);

    expect(lines, contains('${Formatters.price(750)} acima de uma nova (9 %)'));
    expect(lines, contains(startsWith('Não é mais barata do que uma nova')));
  });

  test('an old reference price is marked as possibly outdated', () {
    final lines = newPriceLines(
      listing(price: 7000, newPrice: 8250, checkedAt: checked),
      now: DateTime(2027, 6, 1),
    );

    expect(lines.last, endsWith(': pode estar desatualizado'));
  });
}
