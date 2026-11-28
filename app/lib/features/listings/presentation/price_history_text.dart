import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import '../domain/entities/listing.dart';
import 'listing_labels.dart';
import 'price_history.dart';

/// A line about an earlier price the site reported from before we started
/// tracking; null when there is none or our own history already covers it.
String? siteDropLine(Listing listing, {AppLanguage language = .portuguese}) {
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
  AppLanguage language = .portuguese,
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

/// How far a price moved, in two parts: the arrow with the euros
/// ("↓ 500 €") and the signed share ("−5,9 %"; null when it ended where
/// it began, "0 €") (N.128).
(String euros, String? pct) priceMoveParts(
  double change,
  double changePct, {
  AppLanguage language = .portuguese,
}) {
  final euros = Formatters.price(change.abs(), language: language);
  if (change == 0) return (euros, null);
  final pct = Formatters.percent(
    changePct.abs(),
    decimals: 1,
    language: language,
  );
  return change < 0 ? ('↓ $euros', '−$pct') : ('↑ $euros', '+$pct');
}

/// The move in one line: "↓ 500 € · −5,9 %".
String priceMoveText(
  double change,
  double changePct, {
  AppLanguage language = .portuguese,
}) => switch (priceMoveParts(change, changePct, language: language)) {
  (final euros, final pct?) => '$euros · $pct',
  (final euros, null) => euros,
};

/// A row's move against the real price before it; null for the first
/// price, a placeholder and a return to the same price.
String? priceRowMoveText(
  PriceHistoryRow row, {
  AppLanguage language = .portuguese,
}) => switch (row) {
  PriceHistoryRow(move: .drop || .rise, :final change?, :final changePct?) =>
    priceMoveText(change, changePct, language: language),
  _ => null,
};
