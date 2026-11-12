import 'package:equatable/equatable.dart';

/// The maker's maintenance figures for a catalog model (`motorcycles`'
/// `front_tyre`, `rear_tyre`, `cylinders`, `service_interval_km`,
/// `valve_check_km`, N.60). Any of them may be unknown (a model an account
/// added); the cost of ownership then uses its engine-size figures.
class const BikeMaintenance({
  /// Tyre sizes as "120/70-17".
  final String? frontTyre,
  final String? rearTyre,
  final int? cylinders,
  final int? serviceIntervalKm,
  final int? valveCheckKm,
}) extends Equatable {
  @override
  List<Object?> get props => [
    frontTyre,
    rearTyre,
    cylinders,
    serviceIntervalKm,
    valveCheckKm,
  ];
}
