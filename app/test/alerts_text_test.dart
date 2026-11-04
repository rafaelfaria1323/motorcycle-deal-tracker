import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
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
      ),
    );

    test('the title names the event and the bike', () {
      expect(
        alertTitle(of(AlertType.priceReduction)),
        'Preço reduzido: Yamaha MT-07 · 2021',
      );
      expect(alertTitle(of(AlertType.unknown)), 'Yamaha MT-07 · 2021');
    });

    test('a reduction shows both prices, the rest the price', () {
      expect(
        alertDetailsLine(
          of(
            AlertType.priceReduction,
            oldPrice: 7000,
            newPrice: 6500,
            location: 'Lisboa',
          ),
        ),
        '${Formatters.price(7000)} → ${Formatters.price(6500)} · Lisboa',
      );
      expect(
        alertDetailsLine(of(AlertType.newListing)),
        Formatters.price(6500),
      );
    });

    test('back on the market: the new price and the earlier one', () {
      expect(
        alertTitle(of(AlertType.backOnMarket)),
        'Voltou ao mercado: Yamaha MT-07 · 2021',
      );
      expect(
        alertDetailsLine(
          of(AlertType.backOnMarket, oldPrice: 7000, newPrice: 6500),
        ),
        '${Formatters.price(6500)} (antes ${Formatters.price(7000)})',
      );
      expect(
        alertDetailsLine(of(AlertType.backOnMarket, newPrice: 6500)),
        Formatters.price(6500),
      );
    });

    test('a target price reached: the price and the target', () {
      expect(
        alertTitle(of(AlertType.targetPriceReached)),
        'Chegou ao seu preço: Yamaha MT-07 · 2021',
      );
      expect(
        alertDetailsLine(
          of(AlertType.targetPriceReached, oldPrice: 6600, newPrice: 6500),
        ),
        '${Formatters.price(6500)} (o seu preço: ${Formatters.price(6600)})',
      );
    });

    test('the origin names the saved search, then the time', () {
      final withSearch = of(AlertType.newListing, search: 'MT-07 barata');
      expect(
        alertOriginLine(withSearch),
        '"MT-07 barata" · ${Formatters.time(withSearch.createdAt)}',
      );
      expect(alertOriginLine(of(AlertType.newListing)), isNot(contains('"')));
    });
  });
}
