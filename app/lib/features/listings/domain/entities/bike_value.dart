import 'package:equatable/equatable.dart';

/// What a bike of a model, year and mileage is worth on today's market:
/// the median of the model's live asking prices, each brought to that year
/// and mileage as the fair price does (`bike_value`).
class const BikeValue({
  /// The live listings the estimate comes from.
  required final int comparableCount,

  /// Median of the adjusted prices; null without comparables.
  final double? estimate,

  /// The middle half of the adjusted prices (25th and 75th percentiles).
  final double? low,
  final double? high,
}) extends Equatable {
  @override
  List<Object?> get props => [comparableCount, estimate, low, high];
}
