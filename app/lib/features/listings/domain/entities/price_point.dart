import 'package:equatable/equatable.dart';

class PricePoint extends Equatable {
  const PricePoint({required this.price, required this.observedAt});

  final double price;
  final DateTime observedAt;

  @override
  List<Object?> get props => [price, observedAt];
}
