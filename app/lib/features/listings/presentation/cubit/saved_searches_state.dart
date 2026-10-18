import 'package:equatable/equatable.dart';

import '../../domain/entities/motorcycle_option.dart';
import '../../domain/entities/saved_search.dart';

enum SavedSearchesStatus { initial, loading, success, failure }

class SavedSearchesState extends Equatable {
  const SavedSearchesState({
    this.status = SavedSearchesStatus.initial,
    this.searches = const [],
    this.motorcycles = const [],
    this.matchCounts = const {},
  });

  final SavedSearchesStatus status;
  final List<SavedSearch> searches;

  /// Catalog models, to show a search's model by name.
  final List<MotorcycleOption> motorcycles;

  /// Live listings matching each search, by search id (missing means none).
  final Map<String, int> matchCounts;

  SavedSearchesState copyWith({
    SavedSearchesStatus? status,
    List<SavedSearch>? searches,
    List<MotorcycleOption>? motorcycles,
    Map<String, int>? matchCounts,
  }) {
    return SavedSearchesState(
      status: status ?? this.status,
      searches: searches ?? this.searches,
      motorcycles: motorcycles ?? this.motorcycles,
      matchCounts: matchCounts ?? this.matchCounts,
    );
  }

  @override
  List<Object?> get props => [status, searches, motorcycles, matchCounts];
}
