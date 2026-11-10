import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/core/localization/app_language.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/alerts/domain/entities/listing_alert.dart';
import 'package:motorcycle_deal_tracker/features/alerts/presentation/alerts_text.dart';

ListingAlert alert(String id, DateTime createdAt) => ListingAlert(
  id: id,
  type: AlertType.newListing,
  createdAt: createdAt,
  listing: const Listing(
    id: 'l1',
    source: 'olx',
    url: 'https://www.olx.pt/d/anuncio/x.html',
    brand: 'Yamaha',
    model: 'MT-07',
    status: ListingStatus.active,
    sellerType: SellerType.private,
    images: [],
  ),
);

void main() {
  // Monday 19 October 2026, evening.
  final now = DateTime(2026, 10, 19, 21);

  test('days read as today, yesterday, the weekday, then the date', () {
    expect(alertDayLabel(DateTime(2026, 10, 19, 0, 5), now: now), 'Hoje');
    expect(alertDayLabel(DateTime(2026, 10, 18, 23, 59), now: now), 'Ontem');
    expect(alertDayLabel(DateTime(2026, 10, 15, 12), now: now), 'Quinta-feira');
    expect(alertDayLabel(DateTime(2026, 10, 13, 12), now: now), 'Terça-feira');
    expect(alertDayLabel(DateTime(2026, 10, 12, 12), now: now), '12/10/2026');
  });

  test('days count across the end of a month and of a year', () {
    expect(
      alertDayLabel(DateTime(2026, 10, 30, 12), now: DateTime(2026, 11, 2, 9)),
      'Sexta-feira',
    );
    expect(
      alertDayLabel(DateTime(2026, 12, 31, 12), now: DateTime(2027, 1, 1, 9)),
      'Ontem',
    );
  });

  test('a time later than now (clock skew) reads as today', () {
    expect(alertDayLabel(DateTime(2026, 10, 20, 12), now: now), 'Hoje');
  });

  test('a day across the summer time change is still one day', () {
    // Clocks went back on Sunday 25 October 2026 in Portugal.
    expect(
      alertDayLabel(DateTime(2026, 10, 25, 12), now: DateTime(2026, 10, 26, 1)),
      'Ontem',
    );
  });

  test('alerts are grouped by day in their order', () {
    final days = groupAlertsByDay([
      alert('a', DateTime(2026, 10, 19, 20)),
      alert('b', DateTime(2026, 10, 19, 8)),
      alert('c', DateTime(2026, 10, 18, 22)),
    ], now: now);

    expect(days.map((d) => d.label), ['Hoje', 'Ontem']);
    expect(days.first.alerts.map((a) => a.id), ['a', 'b']);
    expect(days.last.alerts.map((a) => a.id), ['c']);
    expect(groupAlertsByDay(const [], now: now), isEmpty);
  });

  test('an alert shows its local time', () {
    expect(Formatters.time(DateTime(2026, 10, 19, 9, 5)), '09:05');
  });

  group('alert lines', () {
    ListingAlert of(
      AlertType type, {
      double? oldPrice,
      double? newPrice,
      String? search,
      String? location,
      int? mileage,
      int? engineCc,
    }) => ListingAlert(
      id: 'a',
      type: type,
      createdAt: DateTime(2026, 10, 19, 21, 4),
      searchName: search,
      oldPrice: oldPrice,
      newPrice: newPrice,
      listing: Listing(
        id: 'l1',
        source: 'olx',
        url: 'https://www.olx.pt/d/anuncio/x.html',
        brand: 'Yamaha',
        model: 'MT-07',
        status: ListingStatus.active,
        sellerType: SellerType.private,
        images: const [],
        year: 2021,
        price: 6500,
        location: location,
        mileage: mileage,
        engineCc: engineCc,
      ),
    );

    test('the tag names the kind of alert, a drop with its size', () {
      expect(alertKindLabel(of(AlertType.newListing)), 'Novo anúncio');
      expect(
        alertKindLabel(
          of(AlertType.priceReduction, oldPrice: 7000, newPrice: 6400),
        ),
        'Baixa de preço (-${Formatters.price(600)})',
      );
      expect(alertKindLabel(of(AlertType.priceReduction)), 'Baixa de preço');
      expect(
        alertKindLabel(of(AlertType.excellentOpportunity)),
        'Excelente oportunidade',
      );
      expect(
        alertKindLabel(of(AlertType.listingRemoved)),
        'Removido ou vendido',
      );
      expect(alertKindLabel(of(AlertType.backOnMarket)), 'Voltou ao mercado');
      expect(
        alertKindLabel(of(AlertType.targetPriceReached)),
        'Chegou ao seu preço',
      );
      expect(alertKindLabel(of(AlertType.unknown)), isEmpty);
      expect(
        alertKindLabel(
          of(AlertType.priceReduction, oldPrice: 7000, newPrice: 6400),
          language: AppLanguage.english,
        ),
        'Price drop (-${Formatters.price(600, language: AppLanguage.english)})',
      );
      expect(
        alertKindLabel(
          of(AlertType.listingRemoved),
          language: AppLanguage.english,
        ),
        'Removed or sold',
      );
    });

    test('the facts line: place, mileage and engine size when known', () {
      expect(
        alertFactsLine(
          of(
            AlertType.newListing,
            location: 'Braga',
            mileage: 8500,
            engineCc: 689,
          ).listing,
        ),
        'Braga · ${Formatters.mileage(8500)} · 689 cc',
      );
      expect(alertFactsLine(of(AlertType.newListing).listing), isEmpty);
    });

    test('a reduction strikes out the old price, the rest show the price', () {
      final drop = alertPrices(
        of(AlertType.priceReduction, oldPrice: 7000, newPrice: 6500),
      );
      expect(drop.before, Formatters.price(7000));
      expect(drop.now, Formatters.price(6500));
      final listing = alertPrices(of(AlertType.newListing));
      expect(listing.before, isNull);
      expect(listing.now, Formatters.price(6500));
    });

    test('back on the market: the new price and the earlier one', () {
      expect(
        alertPrices(of(AlertType.backOnMarket, oldPrice: 7000, newPrice: 6500))
            .now,
        '${Formatters.price(6500)} (antes ${Formatters.price(7000)})',
      );
      expect(
        alertPrices(of(AlertType.backOnMarket, newPrice: 6500)).now,
        Formatters.price(6500),
      );
    });

    test('a target price reached: the price and the target', () {
      final target = alertPrices(
        of(AlertType.targetPriceReached, oldPrice: 6600, newPrice: 6500),
      );
      expect(target.before, isNull);
      expect(
        target.now,
        '${Formatters.price(6500)} (o seu preço: ${Formatters.price(6600)})',
      );
    });
  });
}
