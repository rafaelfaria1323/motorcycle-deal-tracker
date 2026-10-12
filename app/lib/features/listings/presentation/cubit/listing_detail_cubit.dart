import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/listings_repository.dart';
import 'listing_detail_state.dart';

class ListingDetailCubit extends Cubit<ListingDetailState> {
  ListingDetailCubit(this._repository) : super(const ListingDetailState());

  final ListingsRepository _repository;

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  Future<void> load(String id) async {
    if (!_uuid.hasMatch(id)) {
      emit(const ListingDetailState(status: ListingDetailStatus.notFound));
      return;
    }

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
