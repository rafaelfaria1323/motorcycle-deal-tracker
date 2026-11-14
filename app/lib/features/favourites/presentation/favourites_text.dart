import '../../../core/formatting/formatters.dart';
import '../../listings/domain/entities/listing.dart';
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

/// The planned visit (N.65): "Visita hoje às 18:30", "Visita amanhã às
/// 10:00", "Visita a 20/11/2026 às 09:00"; once its time has gone by,
/// "Visita a 12/11/2026 (já passou)".
String visitText(
  DateTime at, {
  DateTime? now,
  AppLanguage language = .portuguese,
}) {
  final today = now ?? DateTime.now();
  final time = Formatters.time(at);
  if (at.isBefore(today)) {
    return language.messages.visitPast(date: Formatters.date(at));
  }
  return switch (Formatters.calendarDays(today, at)) {
    0 => language.messages.visitToday(time: time),
    1 => language.messages.visitTomorrow(time: time),
    _ => language.messages.visitOn(date: Formatters.date(at), time: time),
  };
}

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

/// What changed in [listing] since the user last opened it as a favourite,
/// [seen] (N.97):
/// "Desde a última vez que o abriu: baixou 500 € · renovado no site".
/// Gone from or back on the market, the price (real prices only), the
/// mileage and a renewal on the site; null when nothing did, or when how
/// it was is unknown.
String? favouriteChangesText(
  FavouriteSeen? seen,
  Listing listing, {
  AppLanguage language = .portuguese,
}) {
  if (seen == null) return null;
  final messages = language.messages;
  const gone = {ListingStatus.removed, ListingStatus.sold};
  const live = {ListingStatus.active, ListingStatus.priceChanged};
  final parts = <String>[
    if (live.contains(seen.status) && gone.contains(listing.status))
      messages.changeGone
    else if (gone.contains(seen.status) && listing.isLive)
      messages.changeBack,
    if ((seen.price, listing.price) case (final before?, final now?)
        when before >= minRealPrice &&
            now >= minRealPrice &&
            (now - before).abs() >= 1)
      now < before
          ? messages.changePriceDown(
              price: Formatters.price(before - now, language: language),
            )
          : messages.changePriceUp(
              price: Formatters.price(now - before, language: language),
            ),
    if ((seen.mileage, listing.mileage) case (final before?, final now?)
        when before != now)
      messages.changeMileage(
        from: Formatters.mileage(before, language: language),
        to: Formatters.mileage(now, language: language),
      ),
    if (listing.siteRefreshedAt case final renewed?
        when listing.isLive && renewed.isAfter(seen.at))
      messages.changeRenewed,
  ];
  if (parts.isEmpty) return null;
  return messages.changesSinceSeen(changes: parts.join(' · '));
}
