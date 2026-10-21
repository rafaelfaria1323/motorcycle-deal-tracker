import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing_alert.dart';

/// One day's alerts under its heading ("Hoje", "Ontem", "Segunda-feira",
/// "03/10/2026").
typedef AlertDay = ({String label, List<ListingAlert> alerts});

const _weekdays = [
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
  'Domingo',
];

/// The heading for the local day of [time].
String alertDayLabel(DateTime time, {DateTime? now}) {
  final today = _day((now ?? DateTime.now()).toLocal());
  final day = _day(time.toLocal());
  final daysAgo = today.difference(day).inDays;

  if (daysAgo <= 0) return 'Hoje';
  if (daysAgo == 1) return 'Ontem';
  if (daysAgo < 7) return _weekdays[day.weekday - 1];
  return Formatters.date(time);
}

/// Alerts grouped by local day, keeping their order (newest first).
List<AlertDay> groupAlertsByDay(List<ListingAlert> alerts, {DateTime? now}) {
  final days = <AlertDay>[];
  for (final alert in alerts) {
    final label = alertDayLabel(alert.createdAt, now: now);
    if (days.isEmpty || days.last.label != label) {
      days.add((label: label, alerts: [alert]));
    } else {
      days.last.alerts.add(alert);
    }
  }
  return days;
}

// Calendar day without the time. UTC arithmetic avoids the 23- or 25-hour
// days of the summer time changes.
DateTime _day(DateTime local) =>
    DateTime.utc(local.year, local.month, local.day);

/// "Preço reduzido: Yamaha MT-07 · 2021".
String alertTitle(ListingAlert alert) {
  final listing = alert.listing;
  final bike = [
    '${listing.brand} ${listing.model}',
    if (listing.year != null) '${listing.year}',
  ].join(' · ');
  return switch (alert.type) {
    AlertType.newListing => 'Novo anúncio: $bike',
    AlertType.priceReduction => 'Preço reduzido: $bike',
    AlertType.excellentOpportunity => 'Excelente oportunidade: $bike',
    AlertType.listingRemoved => 'Anúncio removido: $bike',
    AlertType.backOnMarket => 'Voltou ao mercado: $bike',
    AlertType.targetPriceReached => 'Chegou ao seu preço: $bike',
    AlertType.unknown => bike,
  };
}

/// "7 000 € → 6 500 € · Lisboa": the old and new price for a reduction,
/// otherwise the price, then the place.
String alertDetailsLine(ListingAlert alert) {
  final oldPrice = alert.oldPrice;
  final newPrice = alert.newPrice;
  final price = switch ((alert.type, oldPrice, newPrice)) {
    (AlertType.priceReduction, final old?, final current?) =>
      '${Formatters.price(old)} → ${Formatters.price(current)}',
    // Back on the market: the new price, and what the earlier ad asked.
    (AlertType.backOnMarket, final old?, final current?) =>
      '${Formatters.price(current)} (antes ${Formatters.price(old)})',
    // The target is stored as the old price.
    (AlertType.targetPriceReached, final target?, final current?) =>
      '${Formatters.price(current)} (o seu preço: ${Formatters.price(target)})',
    _ => Formatters.price(newPrice ?? alert.listing.price),
  };
  return [price, ?alert.listing.location].join(' · ');
}

/// '"MT-07 até 7000" · 21:04': the saved search, then the time.
String alertOriginLine(ListingAlert alert) => [
  if (alert.searchName != null) '"${alert.searchName}"',
  Formatters.time(alert.createdAt),
].join(' · ');
