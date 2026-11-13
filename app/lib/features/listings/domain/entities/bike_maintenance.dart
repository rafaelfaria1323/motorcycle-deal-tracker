import 'package:equatable/equatable.dart';

/// The maker's maintenance figures for a catalog model (`motorcycles`'
/// `front_tyre`, `rear_tyre`, `cylinders`, `service_interval_km`,
/// `valve_check_km`, N.60; `fuel_l_per_100km`, N.74). Any of them may be
/// unknown (a model an account added); the cost of ownership then uses its
/// engine-size figures.
class const BikeMaintenance({
  /// Tyre sizes as "120/70-17".
  final String? frontTyre,
  final String? rearTyre,
  final int? cylinders,
  final int? serviceIntervalKm,
  final int? valveCheckKm,

  /// The maker's WMTC consumption, litres per 100 km.
  final double? fuelPer100Km,
}) extends Equatable {
  @override
  List<Object?> get props => [
    frontTyre,
    rearTyre,
    cylinders,
    serviceIntervalKm,
    valveCheckKm,
    fuelPer100Km,
  ];
}
