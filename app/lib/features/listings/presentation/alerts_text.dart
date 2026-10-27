import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing_alert.dart';
import '../../../core/localization/localizations.dart';

String unreadAlertsText(
  int count, {
  AppLanguage language = AppLanguage.portuguese,
}) => language.messages.unreadAlertCount(count: count);

/// One day's alerts under its heading ("Hoje", "Ontem", "Segunda-feira",
/// "03/10/2026").
typedef AlertDay = ({String label, List<ListingAlert> alerts});

List<String> _weekdays({AppLanguage language = AppLanguage.portuguese}) => [
  language.messages.monday,
  language.messages.tuesday,
  language.messages.wednesday,
  language.messages.thursday,
  language.messages.friday,
  language.messages.saturday,
  language.messages.sunday,
];

/// The heading for the local day of [time].
String alertDayLabel(
  DateTime time, {
  DateTime? now,
  AppLanguage language = AppLanguage.portuguese,
}) {
  final today = _day((now ?? DateTime.now()).toLocal());
  final day = _day(time.toLocal());
  final daysAgo = today.difference(day).inDays;

  if (daysAgo <= 0) return language.messages.todayCollectionText;
  if (daysAgo == 1) return language.messages.yesterdayCollectionText;
  if (daysAgo < 7) return _weekdays(language: language)[day.weekday - 1];
  return Formatters.date(time);
}

/// Alerts grouped by local day, keeping their order (newest first).
List<AlertDay> groupAlertsByDay(
  List<ListingAlert> alerts, {
  DateTime? now,
  AppLanguage language = AppLanguage.portuguese,
}) {
  final days = <AlertDay>[];
  for (final alert in alerts) {
    final label = alertDayLabel(alert.createdAt, now: now, language: language);
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
String alertTitle(
  ListingAlert alert, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  final listing = alert.listing;
  final bike = [
    '${listing.brand} ${listing.model}',
    if (listing.year != null) '${listing.year}',
  ].join(' · ');
  return switch (alert.type) {
    AlertType.newListing => language.messages.newListingAlertsText(bike: bike),
    AlertType.priceReduction => language.messages.priceReduced(bike: bike),
    AlertType.excellentOpportunity => language.messages.excellentOpportunity(
      bike: bike,
    ),
    AlertType.listingRemoved => language.messages.listingRemovedAlertsText(
      bike: bike,
    ),
    AlertType.backOnMarket => language.messages.backOnMarket(bike: bike),
    AlertType.targetPriceReached => language.messages.targetPriceReached(
      bike: bike,
    ),
    AlertType.unknown => bike,
  };
}

/// "7 000 € → 6 500 € · Lisboa": the old and new price for a reduction,
/// otherwise the price, then the place.
String alertDetailsLine(
  ListingAlert alert, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  final oldPrice = alert.oldPrice;
  final newPrice = alert.newPrice;
  final price = switch ((alert.type, oldPrice, newPrice)) {
    (AlertType.priceReduction, final old?, final current?) =>
      '${Formatters.price(old, language: language)} → ${Formatters.price(current, language: language)}',
    // Back on the market: the new price, and what the earlier ad asked.
    (AlertType.backOnMarket, final old?, final current?) =>
      language.messages.previously(
        price: Formatters.price(current, language: language),
        price2: Formatters.price(old, language: language),
      ),
    // The target is stored as the old price.
    (AlertType.targetPriceReached, final target?, final current?) =>
      language.messages.yourTarget(
        price: Formatters.price(current, language: language),
        price2: Formatters.price(target, language: language),
      ),
    _ => Formatters.price(newPrice ?? alert.listing.price, language: language),
  };
  return [price, ?alert.listing.location].join(' · ');
}

/// '"MT-07 até 7000" · 21:04': the saved search, then the time.
String alertOriginLine(ListingAlert alert) => [
  if (alert.searchName != null) '"${alert.searchName}"',
  Formatters.time(alert.createdAt),
].join(' · ');
