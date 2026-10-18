import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing_filters.dart';
import '../domain/entities/motorcycle_option.dart';
import 'listing_labels.dart';

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

  return parts.join(' · ');
}
