import 'package:equatable/equatable.dart';

/// What only the owner knows about running a bike, stored per account
/// (`ownership_settings`) and used by the cost of ownership.
class OwnershipSettings extends Equatable {
  const OwnershipSettings({
    this.insurancePerYear,
    this.kmPerYear = defaultKmPerYear,
    this.yearsToKeep = defaultYearsToKeep,
  });

  static const defaultKmPerYear = 5000;
  static const defaultYearsToKeep = 3;

  /// The owner's own insurance quote in euros; null: not given yet.
  final int? insurancePerYear;
  final int kmPerYear;
  final int yearsToKeep;

  @override
  List<Object?> get props => [insurancePerYear, kmPerYear, yearsToKeep];
}
