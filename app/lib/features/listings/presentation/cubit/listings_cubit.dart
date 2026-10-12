import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/listing_filters.dart';
import '../../domain/repositories/listings_repository.dart';
import 'listings_state.dart';

class ListingsCubit extends Cubit<ListingsState> {
  ListingsCubit(this._repository) : super(const ListingsState());

  final ListingsRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: ListingsStatus.loading));
    try {
      final motorcycles = state.motorcycles.isEmpty ? await _repository.getMotorcycleOptions() : state.motorcycles;
      final listings = await _repository.getListings(filters: state.filters, sort: state.sort);
      emit(state.copyWith(status: ListingsStatus.success, listings: listings, motorcycles: motorcycles));
    } catch (_) {
      emit(state.copyWith(status: ListingsStatus.failure));
    }
  }

  Future<void> applyFilters(ListingFilters filters) async {
    emit(state.copyWith(filters: filters));
    await load();
  }
}
