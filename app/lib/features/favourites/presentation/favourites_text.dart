import '../../../core/formatting/formatters.dart';
import '../domain/entities/favourite.dart';
import '../../../core/localization/localizations.dart';

/// "Adicionado aos favoritos há 3 dias".
String favouriteSinceText(
  Favourite favourite, {
  DateTime? now,
  AppLanguage language = .portuguese,
}) => language.messages.addedToFavourites(
  daysago: Formatters.daysAgo(
    favourite.createdAt,
    now: now,
    language: language,
  ),
);

/// The Favoritos page's summary: "3 anúncios, 1 já removido".
String favouritesCountText(
  List<Favourite> favourites, {
  AppLanguage language = .portuguese,
}) {
  final total = favourites.length;
  final removed = favourites.where((f) => f.listing?.isRemoved ?? false).length;
  final count = language.messages.listingCount(count: total);
  if (removed == 0) return count;
  return language.messages.favouritesRemoved(count: count, removed: removed);
}
