import 'package:equatable/equatable.dart';

/// A catalog model the user can pick in the filters.
class const MotorcycleOption({
  required final String id,
  required final String brand,
  required final String model,
}) extends Equatable {
  @override
  List<Object?> get props => [id, brand, model];
}
