import 'package:equatable/equatable.dart';

import '../../../listings/domain/entities/bike_maintenance.dart';

/// What the owner tells about a bike they bought ("Comprei esta", N.67).
class const OwnedBikeDraft({
  required final String motorcycleId,
  required final int year,
  required final DateTime boughtOn,

  /// The ad it was bought from.
  final String? listingId,
  final int? pricePaid,
  final int? mileageAtPurchase,
}) extends Equatable {
  @override
  List<Object?> get props => [
    motorcycleId,
    year,
    boughtOn,
    listingId,
    pricePaid,
    mileageAtPurchase,
  ];
}

/// A month's value of a bike (`owned_bike_values`, N.80): [month] is the
/// month's first day.
typedef MonthlyValue = ({DateTime month, double value});

/// A bike of the account's own (`owned_bikes`), with its model's names
/// and the facts "A minha mota" values and services it by.
class const OwnedBike({
  required final String id,
  required final OwnedBikeDraft purchase,
  required final String brand,
  required final String model,
  final int? engineCc,
  final BikeMaintenance? maintenance,

  /// The values kept once a month, the latest first.
  final List<MonthlyValue> values = const [],
}) extends Equatable {
  String get name => '$brand $model';

  @override
  List<Object?> get props => [
    id,
    purchase,
    brand,
    model,
    engineCc,
    maintenance,
    values,
  ];
}
