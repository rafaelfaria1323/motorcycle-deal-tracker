import 'package:equatable/equatable.dart';

/// What a model's ads left the market at (`exit_price`): the median last
/// asking price of its ads gone in the last 90 days (not relisted, not
/// duplicates), each brought to one year and mileage as the estimate
/// does. Most of them sold, at or a little below that price. Shown only;
/// never a score or the fair value (feature review 5.1).
class const ExitPrice({
  /// The gone ads the median comes from.
  required final int goneCount,

  /// Null when none left.
  final double? median,
}) extends Equatable {
  @override
  List<Object?> get props => [goneCount, median];
}
