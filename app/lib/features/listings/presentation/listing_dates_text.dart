import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import '../../../core/localization/localizations.dart';

/// "18/05/2026 (há 154 dias)".
String dateWithAge(
  DateTime date, {
  DateTime? now,
  AppLanguage language = AppLanguage.portuguese,
}) =>
    '${Formatters.date(date)} (${Formatters.daysAgo(date, now: now, language: language)})';

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

/// For a relisted bike: "Esteve à venda noutro anúncio desde 25/07/2026
/// (há 86 dias), a última vez por 6 500 € (agora menos 300 €)."; null when
/// the listing is not a relist.
String? relistText(
  Listing listing, {
  DateTime? now,
  AppLanguage language = AppLanguage.portuguese,
}) {
  final since = listing.relistedSince;
  if (listing.relistedFrom == null || since == null) return null;
  final text = language.messages.wasForSaleInEarlierListingSince(
    value: dateWithAge(since, now: now, language: language),
  );
  final before = listing.relistedPrice;
  final price = listing.price;
  if (before == null) return '$text.';
  final change = price == null ? 0.0 : price - before;
  final changeText = change.abs() < 1
      ? ''
      : language.messages.now(
          value: change < 0
              ? language.messages.less
              : language.messages.moreListingDatesText,
          price: Formatters.price(change.abs(), language: language),
        );
  return language.messages.lastPricedAt(
    text: text,
    price: Formatters.price(before, language: language),
    changeText: changeText,
  );
}
