import '../../../core/formatting/formatters.dart';
import '../domain/entities/favourite.dart';
import '../../../core/localization/localizations.dart';

/// "Adicionado aos favoritos há 3 dias".
String favouriteSinceText(
  Favourite favourite, {
  DateTime? now,
  AppLanguage language = AppLanguage.portuguese,
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
  AppLanguage language = AppLanguage.portuguese,
}) {
  final total = favourites.length;
  final removed = favourites.where((f) => f.listing?.isRemoved ?? false).length;
  final count = total == 1
      ? language.messages.text1Listing
      : language.messages.listingsDataQualityText(n: (total).toString());
  if (removed == 0) return count;
  return language.messages.already(
    count: count,
    removed: (removed).toString(),
    value: removed == 1
        ? language.messages.removedListing
        : language.messages.removedListingsFavouritesText,
  );
}
