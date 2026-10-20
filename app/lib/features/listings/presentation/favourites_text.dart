import '../../../core/formatting/formatters.dart';
import '../domain/entities/favourite.dart';

/// "Adicionado aos favoritos há 3 dias".
String favouriteSinceText(Favourite favourite, {DateTime? now}) =>
    'Adicionado aos favoritos '
    '${Formatters.daysAgo(favourite.createdAt, now: now)}';

/// The Favoritos page's summary: "3 anúncios, 1 já removido".
String favouritesCountText(List<Favourite> favourites) {
  final total = favourites.length;
  final removed = favourites.where((f) => f.listing?.isRemoved ?? false).length;
  final count = total == 1 ? '1 anúncio' : '$total anúncios';
  if (removed == 0) return count;
  return '$count, $removed já ${removed == 1 ? 'removido' : 'removidos'}';
}
