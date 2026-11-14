import '../entities/favourite.dart';
import '../entities/favourite_share.dart';

/// Favourites shown to one more account, read only (16.11).
abstract interface class FavouriteSharesRepository {
  /// A new link for this account's list (the one not yet used goes).
  Future<String> share();

  /// This account's own share; [FavouriteShare.none] without one.
  Future<FavouriteShare> mine();

  /// Stops showing this account's list to anyone.
  Future<void> stop();

  /// Opens the list of [code]'s owner for this account; its owner's id.
  /// Throws a `PostgrestException` for a link that can't be used.
  Future<String> accept(String code);

  /// The lists other accounts share with this one.
  Future<List<SharedList>> sharedWithMe();

  /// Stops seeing [ownerId]'s list.
  Future<void> leave(String ownerId);

  /// [ownerId]'s favourites, newest first; empty when not shared with
  /// this account.
  Future<List<Favourite>> favouritesOf(String ownerId);
}
