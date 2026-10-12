import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/listings_repository.dart';
import 'listing_detail_state.dart';

class ListingDetailCubit extends Cubit<ListingDetailState> {
  ListingDetailCubit(this._repository) : super(const ListingDetailState());

  final ListingsRepository _repository;

  Future<void> load(String id) async {
    emit(const ListingDetailState());
    try {
      final listing = await _repository.getListingById(id);
      emit(
        listing == null
            ? const ListingDetailState(status: ListingDetailStatus.notFound)
            : ListingDetailState(status: ListingDetailStatus.success, listing: listing),
      );
    } catch (_) {
      emit(const ListingDetailState(status: ListingDetailStatus.failure));
    }
  }
}
