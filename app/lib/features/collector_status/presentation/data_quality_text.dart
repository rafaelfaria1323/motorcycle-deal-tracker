import '../../listings/presentation/listing_labels.dart';
import '../domain/source_quality.dart';
import 'collection_text.dart';
import '../../../core/localization/localizations.dart';

/// "OLX · 120 anúncios ativos"
String qualityTitle(SourceQuality q, {AppLanguage language = .portuguese}) =>
    '${sourceLabel(q.source, language: language)} · '
    '${language.messages.activeListingCount(count: q.liveCount)}';

/// What the site's live listings are: tracked, other models, duplicates.
String qualityMixLine(SourceQuality q, {AppLanguage language = .portuguese}) {
  final parts = [
    language.messages.forTrackedModelsDataQualityText(
      scoredCount: q.scoredCount.toString(),
    ),
    if (q.unmatchedCount > 0)
      language.messages.withoutModel(
        unmatchedCount: q.unmatchedCount.toString(),
        percent: percent(q.unmatchedCount, q.liveCount, language: language),
      ),
    if (q.duplicateCount > 0)
      '${language.messages.duplicateCount(count: q.duplicateCount)} '
          '(${percent(q.duplicateCount, q.liveCount, language: language)})',
  ];
  return parts.join(' · ');
}

/// The facts the scored listings miss; null when none is missing.
String? qualityMissingLine(
  SourceQuality q, {
  AppLanguage language = .portuguese,
}) {
  final parts = [
    if (q.missingYear > 0)
      language.messages.missingYearShare(
        percent: percent(q.missingYear, q.scoredCount, language: language),
      ),
    if (q.missingMileage > 0)
      'km ${percent(q.missingMileage, q.scoredCount, language: language)}',
    if (q.missingLocation > 0)
      language.messages.missingLocationShare(
        percent: percent(q.missingLocation, q.scoredCount, language: language),
      ),
  ];
  if (parts.isEmpty) return null;
  return language.messages.missingFields(fields: parts.join(' · '));
}

/// Null when every listing page has been read.
String? qualityDetailsLine(
  SourceQuality q, {
  AppLanguage language = .portuguese,
}) {
  if (q.detailsPending == 0) return null;
  return language.messages.listingPagesUnread(detailsPending: q.detailsPending);
}

/// Collections run 9 times a day; a day without seeing any listing means
/// the site stopped answering or the collection stopped.
const staleAfter = Duration(hours: 24);

/// When the site's listings were last seen; null before the view had it.
String? qualitySeenLine(
  SourceQuality q,
  DateTime now, {
  AppLanguage language = .portuguese,
}) {
  final seen = q.lastSeenAt;
  if (seen == null) return null;
  final ago = agoText(seen, now: now, language: language);
  if (now.difference(seen) > staleAfter) {
    return language.messages.noListingSeenOnSiteCheckCollection(ago: ago);
  }
  return language.messages.lastListingSeenOnSite(ago: ago);
}

/// Null when no price moved by half or more at once.
String? qualitySharpPricesLine(
  SourceQuality q, {
  AppLanguage language = .portuguese,
}) {
  final n = q.sharpPriceChanges;
  if (n == 0) return null;
  return language.messages.sharpPriceChangesLine(
    listings: language.messages.listingCount(count: n),
  );
}

/// "12 %", rounded; "<1 %" for a small non-zero share.
String percent(int part, int whole, {AppLanguage language = .portuguese}) {
  if (whole <= 0 || part <= 0) return language.messages.zeroPercent;
  final value = part * 100 / whole;
  if (value < 1) return language.messages.lessThanOnePercent;
  return language.messages.percentage(number: value.round().toString());
}
