import 'package:equatable/equatable.dart';

import '../../domain/entities/listing.dart';

enum ListingDetailStatus { loading, success, notFound, failure }

class const ListingDetailState({
  final ListingDetailStatus status = ListingDetailStatus.loading,
  final Listing? listing,
}) extends Equatable {
  @override
  List<Object?> get props => [status, listing];
}
