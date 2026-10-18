import 'package:equatable/equatable.dart';

import '../../domain/entities/listing.dart';

enum ListingDetailStatus { loading, success, notFound, failure }

class ListingDetailState extends Equatable {
  const ListingDetailState({
    this.status = ListingDetailStatus.loading,
    this.listing,
  });

  final ListingDetailStatus status;
  final Listing? listing;

  @override
  List<Object?> get props => [status, listing];
}
