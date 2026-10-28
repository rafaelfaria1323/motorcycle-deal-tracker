import 'package:equatable/equatable.dart';

/// An account's request for a bike's value (`bike_value_requests`): a
/// model nobody collected yet waits for the next collection, which reads
/// its listings and answers it with a notification.
class BikeValueRequest extends Equatable {
  const BikeValueRequest({
    required this.id,
    required this.motorcycleId,
    required this.brand,
    required this.model,
    required this.year,
    required this.requestedAt,
    this.mileage,
    this.answeredAt,
  });

  final String id;
  final String motorcycleId;
  final String brand;
  final String model;
  final int year;
  final int? mileage;
  final DateTime requestedAt;

  /// Null while it waits for a collection.
  final DateTime? answeredAt;

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
class BikeValueRequestLimit implements Exception {
  const BikeValueRequestLimit();
}
