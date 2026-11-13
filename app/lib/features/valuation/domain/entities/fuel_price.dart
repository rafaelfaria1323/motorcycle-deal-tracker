import 'package:equatable/equatable.dart';

/// The national average price of a litre of petrol 95 on [day], as DGEG
/// publishes it (`fuel_prices`, N.74).
class const FuelPrice({
  required final double perLitre,
  required final DateTime day,
}) extends Equatable {
  @override
  List<Object?> get props => [perLitre, day];
}
