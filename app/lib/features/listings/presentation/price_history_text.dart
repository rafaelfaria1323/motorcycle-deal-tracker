import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import 'listing_labels.dart';

/// A line about an earlier price the site reported from before we started
/// tracking; null when there is none or our own history already covers it.
String? siteDropLine(Listing listing) {
  final before = listing.priceBeforeDrop;
  final current = listing.price;
  if (!listing.referenceIsFromSite || before == null || current == null) {
    return null;
  }
  if (before - current < 1) return null;
  final pct = ((before - current) / before * 100).toStringAsFixed(1);
  return 'Segundo o ${sourceLabel(listing.source)}, o preço já foi '
      '${Formatters.price(before)} (−${pct.replaceAll('.', ',')} % até hoje), '
      'antes de começarmos a seguir este anúncio.';
}

/// "Visto pela primeira vez em 03/10/2026 · última vez há 2 dias"; null
/// before the listing was first seen.
String? seenLine(Listing listing, {DateTime? now}) {
  final first = listing.firstSeenAt;
  final last = listing.lastSeenAt;
  if (first == null) return null;
  final firstText = 'Visto pela primeira vez em ${Formatters.date(first)}';
  if (last == null) return firstText;
  return '$firstText · última vez ${Formatters.daysAgo(last, now: now)}';
}
