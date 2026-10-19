import 'package:equatable/equatable.dart';

import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_filters.dart';
import '../../domain/entities/listing_sort.dart';
import '../../domain/entities/motorcycle_option.dart';

enum ListingsStatus { initial, loading, success, failure }

class ListingsState extends Equatable {
  const ListingsState({
    this.status = ListingsStatus.initial,
    this.listings = const [],
    this.motorcycles = const [],
    this.filters = ListingFilters.empty,
    this.sort = ListingSort.dealScoreDesc,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final ListingsStatus status;
  final List<Listing> listings;
  final List<MotorcycleOption> motorcycles;
  final ListingFilters filters;
  final ListingSort sort;

  /// More pages exist after [listings].
  final bool hasMore;

  /// A next page is on its way.
  final bool loadingMore;

  ListingsState copyWith({
    ListingsStatus? status,
    List<Listing>? listings,
    List<MotorcycleOption>? motorcycles,
    ListingFilters? filters,
    ListingSort? sort,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return ListingsState(
      status: status ?? this.status,
      listings: listings ?? this.listings,
      motorcycles: motorcycles ?? this.motorcycles,
      filters: filters ?? this.filters,
      sort: sort ?? this.sort,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
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
  ];
}
