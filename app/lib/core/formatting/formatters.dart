import 'package:intl/intl.dart';

abstract final class Formatters {
  static final _price = NumberFormat.currency(locale: 'pt_PT', symbol: '€', decimalDigits: 0);
  static final _number = NumberFormat.decimalPattern('pt_PT');

  static String price(double? value) => value == null ? '—' : _price.format(value);

  static String mileage(int? value) => value == null ? '—' : '${_number.format(value)} km';
}
