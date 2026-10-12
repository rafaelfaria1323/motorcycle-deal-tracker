import 'package:equatable/equatable.dart';

/// A catalog model the user can pick in the filters.
class MotorcycleOption extends Equatable {
  const MotorcycleOption({
    required this.id,
    required this.brand,
    required this.model,
  });

  final String id;
  final String brand;
  final String model;

  @override
  List<Object?> get props => [id, brand, model];
}