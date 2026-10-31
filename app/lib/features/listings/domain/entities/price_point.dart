import 'package:equatable/equatable.dart';

class const PricePoint({
  required final double price,
  required final DateTime observedAt,
}) extends Equatable {
  @override
  List<Object?> get props => [price, observedAt];
}
