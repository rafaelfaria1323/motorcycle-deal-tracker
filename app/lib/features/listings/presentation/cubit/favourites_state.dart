import 'package:equatable/equatable.dart';

import '../../domain/entities/favourite.dart';

enum FavouritesStatus { initial, loading, success, failure }

class const FavouritesState({
  final FavouritesStatus status = FavouritesStatus.initial,

  /// Newest first.
  final List<Favourite> favourites = const [],
}) extends Equatable {
  Favourite? favouriteOf(String listingId) =>
      favourites.where((f) => f.listingId == listingId).firstOrNull;

  bool isFavourite(String listingId) => favouriteOf(listingId) != null;

  FavouritesState copyWith({
    FavouritesStatus? status,
    List<Favourite>? favourites,
  }) {
    return FavouritesState(
      status: status ?? this.status,
      favourites: favourites ?? this.favourites,
    );
  }

  @override
  List<Object?> get props => [status, favourites];
}
