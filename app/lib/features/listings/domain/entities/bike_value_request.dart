import 'package:equatable/equatable.dart';

/// An account's request for a bike's value (`bike_value_requests`): a
/// model nobody collected yet waits for the next collection, which reads
/// its listings and answers it with a notification.
class const BikeValueRequest({
  required final String id,
  required final String motorcycleId,
  required final String brand,
  required final String model,
  required final int year,
  required final DateTime requestedAt,
  final int? mileage,

  /// Null while it waits for a collection.
  final DateTime? answeredAt,
}) extends Equatable {
  String get name => '$brand $model';

  bool get waiting => answeredAt == null;

  @override
  List<Object?> get props => [
    id,
    motorcycleId,
    brand,
    model,
    year,
    mileage,
    requestedAt,
    answeredAt,
  ];
}

/// Thrown when the account already has as many requests waiting today as
/// the database allows (3).
class const BikeValueRequestLimit() implements Exception;
