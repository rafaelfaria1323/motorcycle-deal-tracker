import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/localizations.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/market_behaviour.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/time_to_sale_text.dart';

TimeToSale sale({PriceBand? band, int? typical = 20, int? remaining = 12}) =>
    TimeToSale(
      band: band,
      goneCount: 8,
      liveCount: 15,
      daysListed: 9,
      typicalDays: typical,
      remainingDays: remaining,
    );

void main() {
  test('the estimate names the price band it comes from', () {
    expect(
      timeToSaleLine(sale(band: PriceBand.below), live: true),
      'Para este anúncio: cerca de 12 dias até sair do mercado (estimativa '
      'pelos anúncios deste modelo abaixo do valor estimado: 8 saíram, 15 '
      'ainda à venda)',
    );
    expect(
      timeToSaleLine(sale(band: PriceBand.above), live: true),
      contains('deste modelo acima do valor estimado:'),
    );
    expect(
      timeToSaleLine(sale(band: PriceBand.near), live: true),
      contains('deste modelo perto do valor estimado:'),
    );
  });

  test('without a band it comes from every ad of the model', () {
    expect(
      timeToSaleLine(sale(remaining: 1), live: true),
      'Para este anúncio: cerca de 1 dia até sair do mercado (estimativa '
      'pelos anúncios deste modelo: 8 saíram, 15 ainda à venda)',
    );
  });

  test('older than the ads that left: no estimate', () {
    expect(
      timeToSaleLine(sale(remaining: null), live: true),
      contains('sem estimativa'),
    );
  });

  test('nothing with too few departures or for a gone listing', () {
    expect(timeToSaleLine(sale(typical: null), live: true), isNull);
    expect(timeToSaleLine(sale(), live: false), isNull);
  });

  test('in English', () {
    expect(
      timeToSaleLine(
        sale(band: PriceBand.near),
        live: true,
        language: AppLanguage.english,
      ),
      'For this listing: about 12 days until it leaves the market '
      "(estimated from this model's listings near the estimated value: "
      '8 left, 15 still for sale)',
    );
  });
}
