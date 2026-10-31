import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import '../../../core/localization/localizations.dart';

/// A list price checked longer ago than this may have changed.
const newPriceStaleAfterDays = 180;

/// Below this discount a new bike, with its factory warranty, is worth
/// comparing.
const smallDiscountPct = 10;

/// Lines comparing the listing's price with a new bike of the same model;
/// empty when either price is unknown (or a placeholder).
List<String> newPriceLines(
  Listing listing, {
  DateTime? now,
  AppLanguage language = .portuguese,
}) {
  final used = listing.askingPrice;
  final fresh = listing.newPrice;
  if (used == null || fresh == null || fresh <= 0) return const [];

  final difference = fresh - used;
  final pct = (difference.abs() / fresh * 100).round();
  final lines = [
    language.messages.newBikePrice(
      price: Formatters.price(fresh, language: language),
    ),
  ];

  if (difference.abs() < 1) {
    lines.add(language.messages.costsSameAsNewOne);
  } else if (difference > 0) {
    lines.add(
      language.messages.belowNewOne(
        price: Formatters.price(difference, language: language),
        percent: Formatters.percent(pct, language: language),
      ),
    );
    if (pct < smallDiscountPct) {
      lines.add(
        language.messages.lessThanBelowNewOneCompareItWith(
          percent: Formatters.percent(smallDiscountPct, language: language),
        ),
      );
    }
  } else {
    lines.add(
      language.messages.aboveNewOne(
        price: Formatters.price(-difference, language: language),
        percent: Formatters.percent(pct, language: language),
      ),
    );
  }
  if (difference < 1) {
    lines.add(language.messages.itIsNotCheaperThanNewOneCheck);
  }

  final checked = listing.newPriceCheckedAt;
  if (checked != null) {
    final age = (now ?? DateTime.now()).difference(checked).inDays;
    lines.add(
      language.messages.newBikePriceCheckedOn(
        date: Formatters.date(checked),
        staleNote: age > newPriceStaleAfterDays
            ? language.messages.itMayBeOutOfDate
            : '',
      ),
    );
  }
  return lines;
}
