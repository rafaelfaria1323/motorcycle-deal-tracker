import 'package:equatable/equatable.dart';

/// The maker's figures for a catalog model (`motorcycles`' `power_kw`,
/// N.63; `torque_nm`, `weight_kg`, `seat_height_mm`, `tank_l`, N.75), for
/// the ad's "Ficha técnica", the comparison and "Cabe-me?". Any of them
/// may be unknown (a model an account added). Consumption is in
/// `BikeMaintenance.fuelPer100Km`.
class const BikeSpecs({
  final double? powerKw,
  final double? torqueNm,

  /// Wet: ready to ride, full tank.
  final int? weightKg,
  final int? seatHeightMm,
  final double? tankLitres,
}) extends Equatable {
  @override
  List<Object?> get props => [
    powerKw,
    torqueNm,
    weightKg,
    seatHeightMm,
    tankLitres,
  ];
}
