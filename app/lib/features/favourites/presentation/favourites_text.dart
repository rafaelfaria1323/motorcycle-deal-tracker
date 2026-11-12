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
