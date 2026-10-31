import 'package:equatable/equatable.dart';

/// What only the owner knows about running a bike, stored per account
/// (`ownership_settings`) and used by the cost of ownership.
class const OwnershipSettings({
  /// The owner's own insurance quote in euros; null: not given yet.
  final int? insurancePerYear,
  final int kmPerYear = defaultKmPerYear,
  final int yearsToKeep = defaultYearsToKeep,
}) extends Equatable {
  static const defaultKmPerYear = 5000;
  static const defaultYearsToKeep = 3;

  @override
  List<Object?> get props => [insurancePerYear, kmPerYear, yearsToKeep];
}
