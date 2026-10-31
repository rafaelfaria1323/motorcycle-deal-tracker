import 'dart:math';

import 'package:equatable/equatable.dart';

import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import 'colour_text.dart';
import '../../../core/localization/localizations.dart';

enum ExplanationTone { positive, negative, neutral }

class const ExplanationLine(final ExplanationTone tone, final String text)
    extends Equatable {
  @override
  List<Object?> get props => [tone, text];
}

class const ScoreExplanation({
  required final int score,
  required final String label,
  required final List<ExplanationLine> lines,
  final int? slicesUsed,
  final int? slicesTotal,
}) extends Equatable {
  @override
  List<Object?> get props => [score, label, lines, slicesUsed, slicesTotal];
}

final _extraLabels = <AppLanguage, Map<String, String>>{};

Map<String, String> extraLabels({
  AppLanguage language = AppLanguage.portuguese,
}) => _extraLabels.putIfAbsent(
  language,
  () => Map<String, String>.unmodifiable({
    'quickshifter': 'quickshifter',
    'exhaust': language.messages.sportsExhaust,
    'luggage': language.messages.luggage,
    'heated_grips': language.messages.heatedGrips,
    'protection': language.messages.protection,
    'new_tyres': language.messages.newTyres,
    'tail_tidy': language.messages.shortPlateHolder,
    'screen': language.messages.tintedOrSportsScreen,
    'levers': language.messages.adjustableLevers,
    'mirrors': language.messages.barEndMirrors,
    'phone_mount': language.messages.phoneMountOrUSB,
    'alarm': language.messages.alarmOrTracker,
    'steering_damper': language.messages.steeringDamper,
    'centre_stand': language.messages.centreStand,
    'cruise_control': 'cruise control',
    'suspension': language.messages.upgradedSuspension,
    'led_indicators': language.messages.ledIndicators,
    'passenger_grips': language.messages.passengerGrabHandles,
    'original_parts': language.messages.originalPartsIncluded,
  }),
);

/// The extras found in the ad ("quickshifter, malas"), or null when none;
/// [key] `valued_extras` gives only the ones that add points.
String? extrasText(
  Map<String, dynamic>? breakdown, {
  String key = 'extras',
  AppLanguage language = AppLanguage.portuguese,
}) {
  final labels = [
    for (final code in (breakdown?[key] as List? ?? const []))
      ?extraLabels(language: language)[code],
  ];
  return labels.isEmpty ? null : labels.join(', ');
}

/// The seller slice: the dealer's score from its ads' warning signs
/// (relists, sharp price changes, repeats, no mileage; `dealer_score`), or
/// null when it was not scored (private seller, fewer than 5 bikes).
ExplanationLine? sellerLine(
  Map<String, dynamic>? breakdown, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  final score = ((breakdown?['scores'] as Map?)?['seller'] as num?)?.round();
  if (score == null) return null;
  final bikes = (breakdown?['dealer_bikes'] as num?)?.toInt();
  final detail =
      '$score/100${bikes == null ? '' : language.messages.acrossBikes(bikes: (bikes).toString())}';
  if (score >= 80) {
    return ExplanationLine(
      ExplanationTone.positive,
      language.messages.dealerWithReliableListings(detail: detail),
    );
  }
  if (score < 50) {
    return ExplanationLine(
      ExplanationTone.negative,
      language.messages.dealerWithManyWarningSignsInItsListings(detail: detail),
    );
  }
  return ExplanationLine(
    ExplanationTone.neutral,
    language.messages.dealerWithSomeWarningSignsInItsListings(detail: detail),
  );
}

/// The kilometres a year that count as normal for a motorcycle (cars do
/// 10-12 000). Keep in step with expected_mileage() in the database.
const normalKmPerYear = 5000;

/// [day] as a decimal year (2 July 2026 is about 2026.5), as
/// decimal_year() in the database.
double decimalYear(DateTime day) =>
    day.year +
    DateTime.utc(
          day.year,
          day.month,
          day.day,
        ).difference(DateTime.utc(day.year)).inDays /
        365.25;

/// The normal mileage of a bike of [year] at [reference] (a decimal year,
/// [decimalYear]): from mid-year registration, never less than one year's.
/// Counted in days, so it doesn't jump on 1 January.
int expectedMileage(int year, num reference) =>
    (max(reference - year - 0.5, 1) * normalKmPerYear).round();

/// How [km] compares with the normal for a bike of [year]: low (half the
/// normal or less), normal (up to 10 % over), high, very high (over twice).
/// Without a year, only a low mileage is said.
ExplanationLine? mileageForAge(
  int? km,
  int? year,
  num reference, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  if (km == null) return null;
  final kmText = Formatters.mileage(km, language: language);
  if (year == null) {
    return km <= normalKmPerYear
        ? ExplanationLine(
            ExplanationTone.positive,
            language.messages.lowMileage(kmText: kmText),
          )
        : null;
  }
  final normal = expectedMileage(year, reference);
  final ratio = km / normal;
  final normalText = language.messages.normalAbout(
    mileage: Formatters.mileage(normal, language: language),
  );
  if (ratio <= 0.5) {
    return ExplanationLine(
      ExplanationTone.positive,
      language.messages.lowMileageForItsYear(
        kmText: kmText,
        normalText: normalText,
      ),
    );
  }
  if (ratio > 2) {
    return ExplanationLine(
      ExplanationTone.negative,
      language.messages.highMileageForItsYear(
        kmText: kmText,
        normalText: normalText,
      ),
    );
  }
  if (ratio > 1.1) {
    return ExplanationLine(
      ExplanationTone.negative,
      language.messages.mileageAboveNormalForItsYear(
        kmText: kmText,
        normalText: normalText,
      ),
    );
  }
  return ExplanationLine(
    ExplanationTone.neutral,
    language.messages.normalMileageForItsYear(kmText: kmText),
  );
}

/// Turns the stored score data into human-readable lines.
/// Only things that actually influence the score are listed.
abstract final class ScoreExplainer {
  static final _riskLineCache =
      <AppLanguage, Map<String, (ExplanationTone, String)>>{};

  static Map<String, (ExplanationTone, String)> _riskLines({
    AppLanguage language = AppLanguage.portuguese,
  }) => _riskLineCache.putIfAbsent(
    language,
    () => Map<String, (ExplanationTone, String)>.unmodifiable({
      'price_far_below_market': (
        ExplanationTone.negative,
        language.messages.priceFarBelowMarketValueCheckThatIt,
      ),
      'price_below_market': (
        ExplanationTone.negative,
        language.messages.priceWellBelowMarketValue,
      ),
      'possible_accident': (
        ExplanationTone.negative,
        language.messages.descriptionMentionsAccidentFallOrImpact,
      ),
      'needs_repair': (
        ExplanationTone.negative,
        language.messages.riskNeedsRepair,
      ),
      'cosmetic_damage': (
        ExplanationTone.negative,
        language.messages.descriptionMentionsScratchesOrDents,
      ),
      'no_mileage': (
        ExplanationTone.negative,
        language.messages.mileageNotStated,
      ),
      'no_year': (ExplanationTone.negative, language.messages.yearNotStated),
      'suspicious_mileage': (
        ExplanationTone.negative,
        language.messages.riskImplausibleMileage,
      ),
      'thin_description': (
        ExplanationTone.negative,
        language.messages.veryShortDescription,
      ),
      'no_location': (
        ExplanationTone.negative,
        language.messages.locationNotStated,
      ),
      'many_owners': (
        ExplanationTone.negative,
        language.messages.threeOrMoreRegisteredOwners,
      ),
      'no_service_book': (
        ExplanationTone.negative,
        language.messages.noCompleteServiceBook,
      ),
      'imported': (ExplanationTone.negative, language.messages.importedBike),
      'text_year_mismatch': (
        ExplanationTone.negative,
        language.messages.riskTextYear,
      ),
      'text_mileage_mismatch': (
        ExplanationTone.negative,
        language.messages.riskTextMoreKm,
      ),
      'text_origin_mismatch': (
        ExplanationTone.negative,
        language.messages.riskTextImported,
      ),
      'text_service_book_mismatch': (
        ExplanationTone.negative,
        language.messages.riskTextNoServiceBook,
      ),
      'relisted': (
        ExplanationTone.negative,
        language.messages.wasForSaleInEarlierListingAndDid,
      ),
      'relisted_often': (
        ExplanationTone.negative,
        language.messages.relistedSeveralTimesOrForSaleForMore,
      ),
      'photos_reused': (
        ExplanationTone.negative,
        language.messages.riskPhotosReused,
      ),
      'a2_limited': (
        ExplanationTone.negative,
        language.messages.a2Version35KWFullPowerRequiresRemoving,
      ),
      'a2_unlocked': (
        ExplanationTone.negative,
        language.messages.riskA2Unlocked,
      ),
      'first_owner': (ExplanationTone.positive, language.messages.firstOwner),
      'service_book': (
        ExplanationTone.positive,
        language.messages.completeServiceBook,
      ),
      'under_warranty': (
        ExplanationTone.positive,
        language.messages.stillUnderFactoryWarranty,
      ),
    }),
  );

  // Presentation thresholds for the wording only; the score itself is
  // calculated in the database.
  static const _priceNoticePct = 3.0;
  static const _minReliableMarket = 3;

  static String label(
    int score, {
    AppLanguage language = AppLanguage.portuguese,
  }) {
    if (score >= 90) return language.messages.excellent;
    if (score >= 80) return language.messages.veryGood;
    if (score >= 70) return language.messages.interesting;
    if (score >= 60) return language.messages.average;
    return language.messages.poor;
  }

  static String riskLabel(
    int risk, {
    AppLanguage language = AppLanguage.portuguese,
  }) {
    if (risk >= 50) return language.messages.highScoreExplanation;
    if (risk >= 20) return language.messages.mediumScoreExplanation;
    return language.messages.lowScoreExplanation;
  }

  static ScoreExplanation? explain(
    Listing listing, {
    DateTime? today,
    AppLanguage language = AppLanguage.portuguese,
  }) {
    final score = listing.dealScore;
    if (score == null) return null;

    final now = today ?? DateTime.now();
    final thisYear = now.year;
    final data = listing.scoreBreakdown ?? const <String, dynamic>{};
    final lines = <ExplanationLine>[];

    // Price vs market
    final undamaged = (data['market_price'] as num?)?.toDouble();
    // With damage in the text the price is judged against the estimate
    // less a repair allowance (damage_allowance).
    final allowance = (data['damage_allowance'] as num?)?.toDouble();
    final damagedValue = (data['damaged_value'] as num?)?.toDouble();
    final damaged = allowance != null && damagedValue != null;
    final pct = damaged
        ? (data['pct_below_damaged_value'] as num?)?.toDouble()
        : (data['pct_below_market'] as num?)?.toDouble();
    final market = damaged ? damagedValue : undamaged;
    final price = listing.price;
    final marketCount = (data['market_listing_count'] as num?)?.toInt();
    // Below 3 comparables the price is not scored, so it is not explained.
    final priceScored =
        marketCount == null || marketCount >= _minReliableMarket;
    if (pct != null && market != null && price != null && priceScored) {
      final amount = Formatters.price(
        (market - price).abs(),
        language: language,
      );
      final pctText = Formatters.percent(pct.abs(), language: language);
      if (pct >= _priceNoticePct) {
        lines.add(
          ExplanationLine(
            ExplanationTone.positive,
            language.messages.belowEstimatedValue(
              pctText: pctText,
              amount: amount,
            ),
          ),
        );
      } else if (pct <= -_priceNoticePct) {
        lines.add(
          ExplanationLine(
            ExplanationTone.negative,
            language.messages.aboveEstimatedValue(
              pctText: pctText,
              amount: amount,
            ),
          ),
        );
      } else {
        lines.add(
          ExplanationLine(
            ExplanationTone.neutral,
            language.messages.priceInLineWithEstimatedValue,
          ),
        );
      }
      lines.add(
        ExplanationLine(
          ExplanationTone.neutral,
          language.messages.estimatedValueForThisYearAndMileageFrom(
            price: Formatters.price(undamaged ?? market, language: language),
          ),
        ),
      );
      if (allowance != null && damagedValue != null) {
        lines.add(
          ExplanationLine(
            ExplanationTone.neutral,
            language.messages.damagedValueWithRepairAllowance(
              percent: Formatters.percent(allowance * 100, language: language),
              price: Formatters.price(damagedValue, language: language),
            ),
          ),
        );
      }
    }
    if (!priceScored) {
      lines.add(
        ExplanationLine(
          ExplanationTone.neutral,
          language.messages.priceNotEnoughComparables(
            marketCount: (marketCount).toString(),
          ),
        ),
      );
    }
    if (data['capped_without_price'] == true) {
      lines.add(
        ExplanationLine(
          ExplanationTone.neutral,
          language.messages.withoutPriceComparisonScoreIsCappedAt70,
        ),
      );
    }
    if (data['capped_for_damage'] == true) {
      lines.add(
        ExplanationLine(
          ExplanationTone.negative,
          language.messages.scoreCappedForDamage,
        ),
      );
    }

    // Mileage, against what is normal for the bike's age
    if (mileageForAge(
          listing.mileage,
          listing.year,
          decimalYear(now),
          language: language,
        )
        case final line?) {
      lines.add(line);
    }

    // Year
    final year = listing.year;
    if (year != null && year >= thisYear) {
      lines.add(
        ExplanationLine(
          ExplanationTone.positive,
          language.messages.modelYear(year: (year).toString()),
        ),
      );
    } else if (year != null && year <= thisYear - 3) {
      lines.add(
        ExplanationLine(
          ExplanationTone.negative,
          language.messages.modelYearOlder(year: (year).toString()),
        ),
      );
    }

    // Version / equipment
    if (extrasText(data, language: language) case final extras?) {
      // Only extras worth money add points (valued_extras).
      final bonus = (data['equipment_bonus'] as num?)?.toInt();
      final valued = extrasText(data, key: 'valued_extras', language: language);
      lines.add(
        ExplanationLine(
          ExplanationTone.positive,
          bonus == null || bonus == 0
              ? language.messages.listedExtras(extras: extras)
              : valued == null
              ? language.messages.listedExtrasScoreExplanation(
                  bonus: (bonus).toString(),
                  extras: extras,
                )
              : language.messages.listedExtrasFor(
                  bonus: (bonus).toString(),
                  valued: valued,
                  extras: extras,
                ),
        ),
      );
    }

    if (sellerLine(data, language: language) case final line?) lines.add(line);
    if (favouriteColourLine(listing, language: language) case final line?) {
      lines.add(line);
    }

    // Risk signals; some are reassuring and read as positives.
    for (final code in (data['risk_reasons'] as List? ?? const [])) {
      final entry = _riskLines(language: language)[code];
      if (entry != null) lines.add(ExplanationLine(entry.$1, entry.$2));
    }

    return ScoreExplanation(
      score: score,
      label: label(score, language: language),
      lines: lines,
      slicesUsed: (data['slices_used'] as num?)?.toInt(),
      slicesTotal: (data['slices_total'] as num?)?.toInt(),
    );
  }
}
