import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing_filters.dart';
import '../domain/entities/motorcycle_option.dart';
import 'listing_labels.dart';
import 'score_criteria.dart';

/// "Yamaha MT-07 · desde 2026 · até 8 000 €" from a set of filters.
String summarizeFilters(
  ListingFilters filters,
  List<MotorcycleOption> motorcycles,
) {
  final parts = <String>[];

  final id = filters.motorcycleId;
  if (id != null) {
    final match = motorcycles.where((m) => m.id == id).firstOrNull;
    if (match != null) parts.add('${match.brand} ${match.model}');
  }
  if (filters.minYear != null) parts.add('desde ${filters.minYear}');
  if (filters.maxPrice != null) {
    parts.add('até ${Formatters.price(filters.maxPrice)}');
  }
  if (filters.maxMileage != null) {
    parts.add('até ${Formatters.mileage(filters.maxMileage)}');
  }
  if (filters.location != null) parts.add(filters.location!);
  if (filters.sellerType != null) parts.add(filters.sellerType!.label);
  final minScore = filters.minDealScore;
  if (minScore != null) parts.add('Deal Score $minScore+');
  final maxRisk = filters.maxRiskScore;
  if (maxRisk != null) parts.add(riskCriterionLabel(maxRisk));

  return parts.join(' · ');
}

/// One applied filter as a removable chip: its label and the filters
/// without it.
typedef FilterChipData = ({String label, ListingFilters without});

/// The applied filters, in the order of [summarizeFilters], each with the
/// filters that remain when it is removed.
List<FilterChipData> filterChips(
  ListingFilters f,
  List<MotorcycleOption> motorcycles,
) {
  ListingFilters copy({
    bool model = true,
    bool year = true,
    bool price = true,
    bool mileage = true,
    bool location = true,
    bool seller = true,
    bool score = true,
    bool risk = true,
    bool activeOnly = false,
  }) => ListingFilters(
    motorcycleId: model ? f.motorcycleId : null,
    minYear: year ? f.minYear : null,
    maxPrice: price ? f.maxPrice : null,
    maxMileage: mileage ? f.maxMileage : null,
    location: location ? f.location : null,
    sellerType: seller ? f.sellerType : null,
    minDealScore: score ? f.minDealScore : null,
    maxRiskScore: risk ? f.maxRiskScore : null,
    activeOnly: activeOnly || f.activeOnly,
  );

  final id = f.motorcycleId;
  final model = id == null
      ? null
      : motorcycles.where((m) => m.id == id).firstOrNull;
  final minScore = f.minDealScore;
  final maxRisk = f.maxRiskScore;

  return [
    if (id != null)
      (
        label: model == null ? 'Modelo' : '${model.brand} ${model.model}',
        without: copy(model: false),
      ),
    if (f.minYear != null)
      (label: 'desde ${f.minYear}', without: copy(year: false)),
    if (f.maxPrice != null)
      (
        label: 'até ${Formatters.price(f.maxPrice)}',
        without: copy(price: false),
      ),
    if (f.maxMileage != null)
      (
        label: 'até ${Formatters.mileage(f.maxMileage)}',
        without: copy(mileage: false),
      ),
    if (f.location != null)
      (label: f.location!, without: copy(location: false)),
    if (f.sellerType != null)
      (label: f.sellerType!.label, without: copy(seller: false)),
    if (minScore != null)
      (label: 'Deal Score $minScore+', without: copy(score: false)),
    if (maxRisk != null)
      (label: riskCriterionLabel(maxRisk), without: copy(risk: false)),
    if (!f.activeOnly)
      (label: 'Inclui removidos', without: copy(activeOnly: true)),
  ];
}
