import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing_filters.dart';
import '../domain/entities/motorcycle_option.dart';
import '../domain/entities/saved_search.dart';
import 'listing_labels.dart';
import 'score_criteria.dart';
import 'score_explanation.dart';
import '../../../core/localization/localizations.dart';

String searchMatchesText(
  int count, {
  AppLanguage language = AppLanguage.portuguese,
}) => language.messages.matchingListingCount(count: count);

String searchNotificationText(
  SavedSearch search, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  final kinds = [
    if (search.notifyNewListing)
      language.messages.newListingsSavedSearchSummary,
    if (search.notifyPriceReduction) language.messages.priceDrops,
    if (search.notifyExcellentDeal) language.messages.opportunities,
    if (search.notifyListingRemoved) language.messages.removedListings,
  ];
  return kinds.isEmpty
      ? language.messages.noAutomaticAlerts
      : kinds.join(' · ');
}

/// "Yamaha MT-07 · desde 2026 · até 8 000 €" from a set of filters.
String summarizeFilters(
  ListingFilters filters,
  List<MotorcycleOption> motorcycles, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  final parts = <String>[];

  final models = modelsText(
    filters.motorcycleIds,
    motorcycles,
    language: language,
  );
  if (models.isNotEmpty) parts.add(models);
  if (filters.minYear != null) {
    parts.add(language.messages.from(minYear: filters.minYear.toString()));
  }
  if (filters.maxPrice != null) {
    parts.add(
      language.messages.upTo(
        price: Formatters.price(filters.maxPrice, language: language),
      ),
    );
  }
  if (filters.maxMileage != null) {
    parts.add(
      language.messages.upTo(
        price: Formatters.mileage(filters.maxMileage, language: language),
      ),
    );
  }
  if (filters.location != null) parts.add(filters.location!);
  if (filters.sellerType != null) {
    parts.add(filters.sellerType!.label(language: language));
  }
  final minScore = filters.minDealScore;
  if (minScore != null) {
    parts.add(
      language.messages.dealScoreSavedSearchSummary(
        minScore: (minScore).toString(),
      ),
    );
  }
  final maxRisk = filters.maxRiskScore;
  if (maxRisk != null) {
    parts.add(riskCriterionLabel(maxRisk, language: language));
  }
  final maxKm = filters.maxDistanceKm;
  if (maxKm != null) parts.add(maxDistanceLabel(maxKm, language: language));
  for (final code in filters.extras) {
    parts.add(extraFilterLabel(code, language: language));
  }
  if (filters.onlyMyColours) parts.add(onlyMyColoursLabel(language: language));

  return parts.join(' · ');
}

/// "Honda CB650R ou CBR650R ou Yamaha MT-07": the models asked for, each
/// brand named once, in the catalog's order; models no longer in the
/// list are left out.
String modelsText(
  List<String> ids,
  List<MotorcycleOption> motorcycles, {
  AppLanguage language = AppLanguage.portuguese,
}) => [
  for (final MapEntry(key: brand, value: models) in modelsByBrand(
    motorcycles.where((m) => ids.contains(m.id)),
  ).entries)
    '$brand ${models.map((m) => m.model).join(language.messages.or)}',
].join(language.messages.or);

/// The models grouped by brand, keeping their order (the filter's chips).
Map<String, List<MotorcycleOption>> modelsByBrand(
  Iterable<MotorcycleOption> motorcycles,
) {
  final byBrand = <String, List<MotorcycleOption>>{};
  for (final m in motorcycles) {
    (byBrand[m.brand] ??= []).add(m);
  }
  return byBrand;
}

/// "Honda CB650R", or "Modelo" for a model no longer in the list.
String modelLabel(
  String id,
  List<MotorcycleOption> motorcycles, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  final m = motorcycles.where((m) => m.id == id).firstOrNull;
  return m == null ? language.messages.model : '${m.brand} ${m.model}';
}

/// The choices of the distance filter, in km.
const maxDistanceOptions = [25, 50, 100, 200, 300];

/// "até 50 km de casa".
String maxDistanceLabel(
  int km, {
  AppLanguage language = AppLanguage.portuguese,
}) => language.messages.withinOfHome(
  mileage: Formatters.mileage(km, language: language),
);

String onlyMyColoursLabel({AppLanguage language = AppLanguage.portuguese}) =>
    language.messages.inYourColours;

/// "com quickshifter".
String extraFilterLabel(
  String code, {
  AppLanguage language = AppLanguage.portuguese,
}) => language.messages.withExtra(
  extra: extraLabels(language: language)[code] ?? code,
);

/// One applied filter as a removable chip: its label and the filters
/// without it.
typedef FilterChipData = ({String label, ListingFilters without});

/// The applied filters, in the order of [(value0, value1) => summarizeFilters(value0, value1, language: language)], each with the
/// filters that remain when it is removed.
List<FilterChipData> filterChips(
  ListingFilters f,
  List<MotorcycleOption> motorcycles, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  ListingFilters copy({
    String? withoutModel,
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
    motorcycleIds: [
      for (final id in f.motorcycleIds)
        if (id != withoutModel) id,
    ],
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

  final minScore = f.minDealScore;
  final maxRisk = f.maxRiskScore;
  final maxKm = f.maxDistanceKm;

  return [
    for (final id in f.motorcycleIds)
      (
        label: modelLabel(id, motorcycles, language: language),
        without: copy(withoutModel: id),
      ),
    if (f.minYear != null)
      (
        label: language.messages.from(minYear: f.minYear.toString()),
        without: copy(year: false),
      ),
    if (f.maxPrice != null)
      (
        label: language.messages.upTo(
          price: Formatters.price(f.maxPrice, language: language),
        ),
        without: copy(price: false),
      ),
    if (f.maxMileage != null)
      (
        label: language.messages.upTo(
          price: Formatters.mileage(f.maxMileage, language: language),
        ),
        without: copy(mileage: false),
      ),
    if (f.location != null)
      (label: f.location!, without: copy(location: false)),
    if (f.sellerType != null)
      (
        label: f.sellerType!.label(language: language),
        without: copy(seller: false),
      ),
    if (minScore != null)
      (
        label: language.messages.dealScoreSavedSearchSummary(
          minScore: (minScore).toString(),
        ),
        without: copy(score: false),
      ),
    if (maxRisk != null)
      (
        label: riskCriterionLabel(maxRisk, language: language),
        without: copy(risk: false),
      ),
    if (maxKm != null)
      (
        label: maxDistanceLabel(maxKm, language: language),
        without: copy(distance: false),
      ),
    for (final code in f.extras)
      (
        label: extraFilterLabel(code, language: language),
        without: copy(withoutExtra: code),
      ),
    if (f.onlyMyColours)
      (
        label: onlyMyColoursLabel(language: language),
        without: copy(colours: false),
      ),
    if (!f.activeOnly)
      (
        label: language.messages.includesRemovedListings,
        without: copy(activeOnly: true),
      ),
  ];
}

/// Localizes only the fallback, never the owner's name.
String savedSearchName(
  SavedSearch search, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  final name = search.name;
  return name == null || name.trim().isEmpty
      ? language.messages.unnamedSearch
      : name;
}

/// Said when a search would repeat [existing].
String alreadySavedText(
  SavedSearch existing, {
  AppLanguage language = AppLanguage.portuguese,
}) => language.messages.thisSearchIsAlreadySavedAs(
  displayName: savedSearchName(existing, language: language),
);
