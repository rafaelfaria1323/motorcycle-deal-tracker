import 'package:equatable/equatable.dart';

/// One slice of the Deal Score (N.126): its score out of 100, its share of
/// the weights in use and the points it brings, with how it was reached.
/// A slice without data has no figures and says why it doesn't count.
class const ScoreBreakdownRow({
  required final String label,
  required final List<String> details,
  final String? score,
  final String? share,
  final String? points,
}) extends Equatable {
  bool get counted => score != null;

  @override
  List<Object?> get props => [label, details, score, share, points];
}

/// A line under the slices: the weighted average, the equipment bonus, a
/// cap and the final score ([isResult]).
class const ScoreBreakdownTotal(
  final String label,
  final String value, {
  final bool isResult = false,
}) extends Equatable {
  @override
  List<Object?> get props => [label, value, isResult];
}

class const ScoreBreakdown({
  required final List<ScoreBreakdownRow> rows,
  required final List<ScoreBreakdownTotal> totals,
}) extends Equatable {
  @override
  List<Object?> get props => [rows, totals];
}
