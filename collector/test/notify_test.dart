import 'package:collector/collector.dart';
import 'package:test/test.dart';

PendingAlert alert(String type, {double? oldPrice, double? newPrice}) =>
    PendingAlert(
      alertId: 'a1',
      type: type,
      brand: 'Yamaha',
      model: 'MT-07',
      url: 'https://www.standvirtual.com/motos/anuncio/x.html',
      oldPrice: oldPrice,
      newPrice: newPrice,
      year: 2024,
      mileage: 5000,
      price: 6800,
      dealScore: 87,
      location: 'Viseu',
    );

void main() {
  test('euros groups thousands', () {
    expect(euros(6800), '6 800 €');
    expect(euros(12500.4), '12 500 €');
    expect(euros(950), '950 €');
  });

  test('a new listing shows price, facts, score and link', () {
    expect(
      formatAlert(alert('new_listing', newPrice: 6800)),
      '🆕 Novo anúncio: Yamaha MT-07 2024\n'
      '6 800 €\n'
      '5 000 km · Viseu · Pontuação 87\n'
      'https://www.standvirtual.com/motos/anuncio/x.html',
    );
  });

  test('a price drop shows old and new price', () {
    final text = formatAlert(
      alert('price_reduction', oldPrice: 7200, newPrice: 6800),
    );
    expect(text.split('\n')[1], '7 200 € → 6 800 €');
  });

  test('a removed listing shows no score', () {
    final text = formatAlert(alert('listing_removed', newPrice: 6800));
    expect(text, isNot(contains('Pontuação')));
  });
}
