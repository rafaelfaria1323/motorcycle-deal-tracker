import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_alert.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/alerts_text.dart';

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
}
