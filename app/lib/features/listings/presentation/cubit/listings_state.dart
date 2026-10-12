import 'package:equatable/equatable.dart';

import '../../domain/entities/listing.dart';

enum ListingsStatus { initial, loading, success, failure }

class ListingsState extends Equatable {
  const ListingsState({this.status = ListingsStatus.initial, this.listings = const []});

  final ListingsStatus status;
  final List<Listing> listings;

  ListingsState copyWith({ListingsStatus? status, List<Listing>? listings}) {
    return ListingsState(status: status ?? this.status, listings: listings ?? this.listings);
  }

  @override
  List<Object?> get props => [status, listings];
}
