import '../store/push_store.dart';
import 'notification_text.dart';
import 'push_test.dart';
import 'web_push.dart';

/// A month's value of an account's own bike (N.80, "A minha mota"), with
/// the latest earlier month's when there is one.
class const OwnedBikeValue({
  required final String userId,
  required final String bikeId,
  required final String brand,
  required final String model,
  required final int year,
  required final double value,
  final int? mileage,
  final double? previousValue,

  /// The first day of the month [previousValue] is for.
  final DateTime? previousMonth,
}) {
  /// A row of `record_owned_bike_values`.
  factory OwnedBikeValue.fromRow(Map<String, dynamic> row) => OwnedBikeValue(
    userId: row['user_id'] as String,
    bikeId: row['bike_id'] as String,
    brand: row['brand'] as String,
    model: row['model'] as String,
    year: (row['year'] as num).toInt(),
    value: (row['value'] as num).toDouble(),
    mileage: (row['mileage'] as num?)?.toInt(),
    previousValue: (row['previous_value'] as num?)?.toDouble(),
    previousMonth: switch (row['previous_month']) {
      final String date => DateTime.parse(date),
      _ => null,
    },
  );
}

/// Values are estimates: told to the nearest 10 €, as the app's
/// `roughPrice`.
double _rough(double value) => (value / 10).round() * 10.0;

/// The monthly notification: what the bike is worth now and how much that
/// changed since the month before ("Mais ou menos o mesmo" within 1 %, as
/// the app's change against the price paid); a tap opens "A minha mota".
Map<String, Object?> ownedBikeValuePush(
  OwnedBikeValue bike, {
  NotificationLanguage language = .portuguese,
}) {
  final name = '${bike.brand} ${bike.model} ${bike.year}';
  final previous = bike.previousValue;
  final month = bike.previousMonth;
  final String body;
  if (previous == null || previous <= 0 || month == null) {
    body = switch (bike.mileage) {
      final km? => language.ownedBikeValueFirst('${language.number(km)} km'),
      null => language.ownedBikeValueFirstNoMileage,
    };
  } else {
    final change = bike.value - previous;
    final share = change / previous;
    final monthName = language.monthName(month.month);
    if (share.abs() < 0.01) {
      body = language.ownedBikeValueSame(monthName);
    } else {
      final amount = language.currency(_rough(change.abs()));
      final percent = language.percent(share.abs() * 100);
      body = change < 0
          ? language.ownedBikeValueDown(amount, percent, monthName)
          : language.ownedBikeValueUp(amount, percent, monthName);
    }
  }
  return {
    'title': language.ownedBikeValueTitle(
      name,
      language.currency(_rough(bike.value)),
    ),
    'body': body,
    'url': '/#/my-bike',
    'tag': 'bike-month-${bike.bikeId}',
    'language': language.code,
  };
}

/// Keeps this month's value of every bike that has none yet
/// (`record_owned_bike_values` at [at]) and tells each owner on their
/// devices, one notification per bike. Without Web Push ([push] null) the
/// values are still kept: the app shows them.
Future<({int valued, int sent})> sendOwnedBikeValues(
  PushStore store,
  WebPushSender? push,
  DateTime at,
) async {
  final values = await store.recordOwnedBikeValues(at);
  if (push == null) return (valued: values.length, sent: 0);
  var sent = 0;
  for (final bike in values) {
    final result = await pushToUsers(store, push, [
      bike.userId,
    ], (_, language) => ownedBikeValuePush(bike, language: language));
    sent += result.sent;
  }
  return (valued: values.length, sent: sent);
}
