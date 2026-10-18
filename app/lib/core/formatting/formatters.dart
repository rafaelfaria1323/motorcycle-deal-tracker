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

  static String mileage(int? value) =>
      value == null ? '—' : '${_number.format(value)} km';

  static final _date = DateFormat('dd/MM/yyyy');

  static String date(DateTime value) => _date.format(value.toLocal());

  static String daysAgo(DateTime value, {DateTime? now}) {
    final days = (now ?? DateTime.now()).difference(value).inDays;
    if (days <= 0) return 'hoje';
    if (days == 1) return 'ontem';
    return 'há $days dias';
  }

  static String formatDate(DateTime date) =>
      DateFormat.yMMMd('pt_PT').format(date);
}
