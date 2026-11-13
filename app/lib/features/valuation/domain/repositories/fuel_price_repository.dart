import '../entities/fuel_price.dart';

abstract interface class FuelPriceRepository {
  /// The latest national average price of petrol 95; null when none is
  /// stored yet.
  Future<FuelPrice?> latest();
}
