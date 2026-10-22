import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing_filters.dart';
import '../domain/entities/motorcycle_option.dart';
import 'listing_labels.dart';
import 'score_criteria.dart';
import 'score_explanation.dart';

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
  final maxKm = filters.maxDistanceKm;
  if (maxKm != null) parts.add(maxDistanceLabel(maxKm));
  for (final code in filters.extras) {
    parts.add(extraFilterLabel(code));
  }
  if (filters.onlyMyColours) parts.add(onlyMyColoursLabel);

  return parts.join(' · ');
}

/// The choices of the distance filter, in km.
const maxDistanceOptions = [25, 50, 100, 200, 300];

/// "até 50 km de casa".
String maxDistanceLabel(int km) => 'até ${Formatters.mileage(km)} de casa';

const onlyMyColoursLabel = 'nas suas cores';

/// "com quickshifter".
String extraFilterLabel(String code) => 'com ${extraLabels[code] ?? code}';

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
    bool distance = true,
    String? withoutExtra,
    bool colours = true,
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
    maxDistanceKm: distance ? f.maxDistanceKm : null,
    extras: [
      for (final e in f.extras)
        if (e != withoutExtra) e,
    ],
    onlyMyColours: colours && f.onlyMyColours,
    activeOnly: activeOnly || f.activeOnly,
  );

  final id = f.motorcycleId;
  final model = id == null
      ? null
      : motorcycles.where((m) => m.id == id).firstOrNull;
  final minScore = f.minDealScore;
  final maxRisk = f.maxRiskScore;
  final maxKm = f.maxDistanceKm;

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
    if (maxKm != null)
      (label: maxDistanceLabel(maxKm), without: copy(distance: false)),
    for (final code in f.extras)
      (label: extraFilterLabel(code), without: copy(withoutExtra: code)),
    if (f.onlyMyColours)
      (label: onlyMyColoursLabel, without: copy(colours: false)),
    if (!f.activeOnly)
      (label: 'Inclui removidos', without: copy(activeOnly: true)),
  ];
}
