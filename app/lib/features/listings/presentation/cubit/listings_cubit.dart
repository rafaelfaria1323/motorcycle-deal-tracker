import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/listing_sort.dart';
import '../../domain/repositories/listings_repository.dart';
import 'listings_state.dart';

class ListingsCubit extends Cubit<ListingsState> {
  ListingsCubit(this._repository) : super(const ListingsState());

  final ListingsRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: ListingsStatus.loading));
    try {
      final listings = await _repository.getListings(sort: ListingSort.dealScoreDesc);
      emit(state.copyWith(status: ListingsStatus.success, listings: listings));
    } catch (_) {
      emit(state.copyWith(status: ListingsStatus.failure));
    }
  }
}
