import 'package:equatable/equatable.dart';

/// A recall of the listing's model from the EU's Safety Gate (N.86,
/// `vehicle_recalls`, read by `refresh_vehicle_recalls()`): what the
/// Commission published, in its words, never translated by us. [applies]
/// says whether it can cover the listing's year (its production dates
/// hold it, or name no years); the others are the model's other years.
class const VehicleRecall({
  required final String caseNumber,
  required final DateTime publishedOn,
  required final String name,
  required final String alertUrl,
  required final bool applies,
  final String? productionDates,
  final String? recallCode,
  final String? dangerEn,
  final String? dangerPt,
  final String? countryEn,
  final String? countryPt,
}) extends Equatable {
  @override
  List<Object?> get props => [caseNumber, applies];
}
