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
