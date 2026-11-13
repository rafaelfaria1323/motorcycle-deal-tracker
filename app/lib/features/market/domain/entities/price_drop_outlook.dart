import 'package:equatable/equatable.dart';

/// What the model's other ads did in the [days] after they were as old as
/// this one (`price_drop_outlook`, N.83): dropped their price by 1 % or
/// more, else left the market, else stayed as they were. Asking prices,
/// not sales. Shown only; never a score.
class const PriceDropOutlook({
  required final int sample,
  required final int dropped,
  required final int gone,
  required final int unchanged,

  /// The median drop of those that dropped, in %; null when none did.
  final double? medianDrop,
  final int days = 30,
}) extends Equatable {
  @override
  List<Object?> get props => [
    sample,
    dropped,
    gone,
    unchanged,
    medianDrop,
    days,
  ];
}
