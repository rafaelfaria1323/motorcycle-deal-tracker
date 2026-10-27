import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import 'listing_labels.dart';
import '../../../core/localization/localizations.dart';

/// A line about an earlier price the site reported from before we started
/// tracking; null when there is none or our own history already covers it.
String? siteDropLine(
  Listing listing, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  final before = listing.priceBeforeDrop;
  final current = listing.price;
  if (!listing.referenceIsFromSite || before == null || current == null) {
    return null;
  }
  if (before - current < 1) return null;
  final pct = Formatters.percent(
    (before - current) / before * 100,
    decimals: 1,
    language: language,
  );
  return language.messages.siteDropLine(
    site: sourceLabel(listing.source, language: language),
    price: Formatters.price(before, language: language),
    pct: pct,
  );
}

/// "Visto pela primeira vez em 03/10/2026 · última vez há 2 dias"; null
/// before the listing was first seen.
String? seenLine(
  Listing listing, {
  DateTime? now,
  AppLanguage language = AppLanguage.portuguese,
}) {
  final first = listing.firstSeenAt;
  final last = listing.lastSeenAt;
  if (first == null) return null;
  final firstText = language.messages.firstSeenOn(date: Formatters.date(first));
  if (last == null) return firstText;
  return language.messages.lastSeen(
    firstText: firstText,
    daysago: Formatters.daysAgo(last, now: now, language: language),
  );
}
