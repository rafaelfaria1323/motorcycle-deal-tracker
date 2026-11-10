import '../../../core/formatting/formatters.dart';
import '../../listings/domain/entities/listing.dart';
import '../domain/entities/listing_alert.dart';
import '../../../core/localization/localizations.dart';

String unreadAlertsText(int count, {AppLanguage language = .portuguese}) =>
    language.messages.unreadAlertCount(count: count);

/// One day's alerts under its heading ("Hoje", "Ontem", "Segunda-feira",
/// "03/10/2026").
typedef AlertDay = ({String label, List<ListingAlert> alerts});

List<String> _weekdays({AppLanguage language = .portuguese}) => [
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
  AppLanguage language = .portuguese,
}) {
  final today = _day((now ?? DateTime.now()).toLocal());
  final day = _day(time.toLocal());
  final daysAgo = today.difference(day).inDays;

  if (daysAgo <= 0) return language.messages.todayHeading;
  if (daysAgo == 1) return language.messages.yesterdayHeading;
  if (daysAgo < 7) return _weekdays(language: language)[day.weekday - 1];
  return Formatters.date(time);
}

/// Alerts grouped by local day, keeping their order (newest first).
List<AlertDay> groupAlertsByDay(
  List<ListingAlert> alerts, {
  DateTime? now,
  AppLanguage language = .portuguese,
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

/// The tag on an alert's card: "Novo anúncio", "Baixa de preço (-600 €)".
String alertKindLabel(
  ListingAlert alert, {
  AppLanguage language = .portuguese,
}) {
  final messages = language.messages;
  return switch (alert.type) {
    AlertType.newListing => messages.alertKindNew,
    AlertType.priceReduction => switch ((alert.oldPrice, alert.newPrice)) {
      (final old?, final current?) when old > current =>
        messages.alertKindDropBy(
          amount: '-${Formatters.price(old - current, language: language)}',
        ),
      _ => messages.alertKindDrop,
    },
    AlertType.excellentOpportunity => messages.alertKindExcellent,
    AlertType.listingRemoved => messages.alertKindRemoved,
    AlertType.backOnMarket => messages.alertKindBack,
    AlertType.targetPriceReached => messages.alertKindTarget,
    AlertType.unknown => '',
  };
}

/// "Braga · 8 500 km · 649 cc": what is known of the place and the bike.
String alertFactsLine(Listing listing, {AppLanguage language = .portuguese}) =>
    [
      ?listing.location,
      if (listing.mileage != null)
        Formatters.mileage(listing.mileage, language: language),
      if (listing.engineCc case final cc?) '$cc cc',
    ].join(' · ');

/// The card's prices: [before] struck out for a reduction ("7 000 €"),
/// then the price now, with the earlier ad's price or the person's target
/// beside it when the alert is about one of them.
({String? before, String now}) alertPrices(
  ListingAlert alert, {
  AppLanguage language = .portuguese,
}) {
  String price(double value) => Formatters.price(value, language: language);
  return switch ((alert.type, alert.oldPrice, alert.newPrice)) {
    (AlertType.priceReduction, final old?, final current?) => (
      before: price(old),
      now: price(current),
    ),
    // Back on the market: the new price, and what the earlier ad asked.
    (AlertType.backOnMarket, final old?, final current?) => (
      before: null,
      now: language.messages.previously(
        price: price(current),
        price2: price(old),
      ),
    ),
    // The target is stored as the old price.
    (AlertType.targetPriceReached, final target?, final current?) => (
      before: null,
      now: language.messages.yourTarget(
        price: price(current),
        price2: price(target),
      ),
    ),
    _ => (
      before: null,
      now: Formatters.price(
        alert.newPrice ?? alert.listing.price,
        language: language,
      ),
    ),
  };
}
