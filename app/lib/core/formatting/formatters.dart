import 'package:intl/intl.dart';

abstract final class Formatters {
  static final _price = NumberFormat.currency(
    locale: 'pt_PT',
    symbol: '€',
    decimalDigits: 0,
  );
  static final _number = NumberFormat.decimalPattern('pt_PT');

  static String price(double? value) =>
      value == null ? '—' : _price.format(value);

  /// "5,3 %": decimal comma and a space before the sign, as in pt-PT.
  static String percent(num value, {int decimals = 0}) =>
      '${value.toStringAsFixed(decimals).replaceAll('.', ',')} %';

  static String mileage(int? value) =>
      value == null ? '—' : '${_number.format(value)} km';

  static final _date = DateFormat('dd/MM/yyyy');

  static String date(DateTime value) => _date.format(value.toLocal());

  static final _time = DateFormat('HH:mm');

  /// "09:05", local time.
  static String time(DateTime value) => _time.format(value.toLocal());

  /// Calendar days from [from]'s local day to [to]'s (1 = the next day),
  /// right across a change to or from summer time, when a day has 23 or
  /// 25 hours.
  static int calendarDays(DateTime from, DateTime to) {
    DateTime day(DateTime t) {
      final local = t.toLocal();
      return DateTime.utc(local.year, local.month, local.day);
    }

    return day(to).difference(day(from)).inDays;
  }

  static String daysAgo(DateTime value, {DateTime? now}) {
    final days = (now ?? DateTime.now()).difference(value).inDays;
    if (days <= 0) return 'hoje';
    if (days == 1) return 'ontem';
    return 'há $days dias';
  }
}
