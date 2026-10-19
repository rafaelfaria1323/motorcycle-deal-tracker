import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';

/// "18/05/2026 (há 154 dias)".
String dateWithAge(DateTime date, {DateTime? now}) =>
    '${Formatters.date(date)} (${Formatters.daysAgo(date, now: now)})';

/// The site's renewal date when it is worth showing: at least a day after
/// the publication (OLX dates and sorts ads by their last renewal, so this
/// is the date OLX shows).
DateTime? renewalToShow(Listing listing) {
  final renewed = listing.siteRefreshedAt;
  final published = listing.publishedAt;
  if (renewed == null) return null;
  if (published != null &&
      renewed.difference(published) < const Duration(days: 1)) {
    return null;
  }
  return renewed;
}
