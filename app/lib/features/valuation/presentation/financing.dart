import 'dart:math';

/// How long a loan can run, in months: what banks and dealers offer for a
/// motorcycle in Portugal.
const financingMonths = [12, 24, 36, 48, 60, 72, 84];

/// The term the calculator opens on.
const defaultFinancingMonths = 48;

/// What paying [price] in instalments costs.
class const FinancingCost({
  required final double price,
  required final double deposit,
  required final int months,

  /// The TAEG, as a fraction.
  required final double apr,

  /// The monthly instalment (0 when the deposit covers the price).
  required final double monthly,
}) {
  /// What is borrowed.
  double get financed => max(price - deposit, 0);

  /// The deposit plus every instalment.
  double get totalPaid => min(deposit, price) + monthly * months;

  /// What the loan costs on top of paying at once.
  double get interest => monthly * months - financed;

  bool get nothingFinanced => financed == 0;
}

/// [price] paid with [deposit] down and the rest over [months] at [apr], the
/// TAEG as a fraction (0.119 for 11,9 %). The TAEG is an effective yearly
/// rate that already counts the loan's fees, so the month's rate is its
/// twelfth root ((1 + TAEG)^(1/12) - 1), not a twelfth of it.
FinancingCost financingCost({
  required double price,
  required double deposit,
  required int months,
  required double apr,
}) {
  final financed = max(price - deposit, 0.0);
  final rate = pow(1 + apr, 1 / 12) - 1;
  final monthly = financed == 0
      ? 0.0
      : rate == 0
      ? financed / months
      : financed * rate / (1 - pow(1 + rate, -months));
  return FinancingCost(
    price: price,
    deposit: deposit,
    months: months,
    apr: apr,
    monthly: monthly,
  );
}

/// A yearly rate as typed ("11,9", "11.9 %", "0"), as a fraction; null when
/// it isn't one or is above 100 %.
double? parseRate(String text) {
  final value = text
      .trim()
      .replaceAll(RegExp(r'\s|%'), '')
      .replaceAll(',', '.');
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) return null;
  final percent = double.parse(value);
  return percent > 100 ? null : percent / 100;
}
