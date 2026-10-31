import 'package:equatable/equatable.dart';

import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_filters.dart';
import '../../domain/entities/listing_sort.dart';
import '../../domain/entities/motorcycle_option.dart';

enum ListingsStatus { initial, loading, success, failure }

class const ListingsState({
  final ListingsStatus status = ListingsStatus.initial,
  final List<Listing> listings = const [],
  final List<MotorcycleOption> motorcycles = const [],
  final ListingFilters filters = ListingFilters.empty,
  final ListingSort sort = ListingSort.dealScoreDesc,

  /// More pages exist after [listings].
  final bool hasMore = false,

  /// A next page is on its way.
  final bool loadingMore = false,

  /// Ads first seen since [listings] loaded, matching the same filters
  /// (counted on return to the app after a while; 0 until then).
  final int newCount = 0,
}) extends Equatable {
  ListingsState copyWith({
    ListingsStatus? status,
    List<Listing>? listings,
    List<MotorcycleOption>? motorcycles,
    ListingFilters? filters,
    ListingSort? sort,
    bool? hasMore,
    bool? loadingMore,
    int? newCount,
  }) {
    return ListingsState(
      status: status ?? this.status,
      listings: listings ?? this.listings,
      motorcycles: motorcycles ?? this.motorcycles,
      filters: filters ?? this.filters,
      sort: sort ?? this.sort,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      newCount: newCount ?? this.newCount,
    );
  }

  @override
  List<Object?> get props => [
    status,
    listings,
    motorcycles,
    filters,
    sort,
    hasMore,
    loadingMore,
    newCount,
  ];
}
