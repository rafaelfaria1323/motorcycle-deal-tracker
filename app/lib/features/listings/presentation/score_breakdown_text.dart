import 'package:equatable/equatable.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import '../domain/entities/listing.dart';
import 'score_explanation.dart';

/// One slice of the Deal Score (N.126): its score out of 100, its share of
/// the weights in use and the points it brings, with how it was reached.
/// A slice without data has no figures and says why it doesn't count.
class const ScoreBreakdownRow({
  required final String label,
  required final List<String> details,
  final String? score,
  final String? share,
  final String? points,
}) extends Equatable {
  bool get counted => score != null;

  @override
  List<Object?> get props => [label, details, score, share, points];
}

/// A line under the slices: the weighted average, the equipment bonus, a
/// cap and the final score ([isResult]).
class const ScoreBreakdownTotal(
  final String label,
  final String value, {
  final bool isResult = false,
}) extends Equatable {
  @override
  List<Object?> get props => [label, value, isResult];
}

class const ScoreBreakdown({
  required final List<ScoreBreakdownRow> rows,
  required final List<ScoreBreakdownTotal> totals,
}) extends Equatable {
  @override
  List<Object?> get props => [rows, totals];
}

/// The slices in the database's order, with the weights
/// combine_deal_score() uses when a breakdown doesn't carry its own.
const _slices = {'price': 35, 'year_mileage': 20, 'risk': 10, 'seller': 10};

/// The Deal Score's whole calculation from the stored breakdown
/// (combine_deal_score() and recalculate_deal_scores()), or null for an
/// unscored listing. The slices' points add up to the weighted average;
/// the equipment bonus and any cap then give the score.
ScoreBreakdown? scoreBreakdownOf(
  Listing listing, {
  AppLanguage language = .portuguese,
}) {
  final score = listing.dealScore;
  final data = listing.scoreBreakdown;
  if (score == null || data == null) return null;
  final scores = (data['scores'] as Map?) ?? const {};
  if (scores.isEmpty) return null;
  final weights = (data['weights'] as Map?) ?? const {};
  final messages = language.messages;

  double? scoreOf(String slice) => (scores[slice] as num?)?.toDouble();
  double weightOf(String slice) =>
      ((weights[slice] as num?) ?? _slices[slice]!).toDouble();
  final usedWeight = [
    for (final slice in _slices.keys)
      if (scoreOf(slice) != null) weightOf(slice),
  ].fold<double>(0, (sum, weight) => sum + weight);

  String number(num value) => Formatters.decimal(
    value,
    decimals: value == value.roundToDouble() ? 0 : 1,
    language: language,
  );
  String outOf100(num value) => messages.scoreOutOf100(score: number(value));
  String percent(num value) => Formatters.percent(value, language: language);

  final rows = <ScoreBreakdownRow>[];
  var weighted = 0.0;
  for (final slice in _slices.keys) {
    final label = switch (slice) {
      'price' => messages.scoreSlicePrice,
      'year_mileage' => messages.scoreSliceYearMileage,
      'risk' => messages.scoreSliceRisk,
      _ => messages.scoreSliceSeller,
    };
    final sliceScore = scoreOf(slice);
    if (sliceScore == null) {
      rows.add(
        ScoreBreakdownRow(
          label: label,
          details: [_notCounted(slice, listing, data, language)],
        ),
      );
      continue;
    }
    final share = weightOf(slice) / usedWeight;
    final points = sliceScore * share;
    weighted += points;
    rows.add(
      ScoreBreakdownRow(
        label: label,
        score: outOf100(sliceScore),
        share: messages.scoreWeight(share: percent(share * 100)),
        points: messages.scorePoints(
          points: Formatters.decimal(points, language: language),
        ),
        details: switch (slice) {
          'price' => _priceDetails(listing, data, language),
          'year_mileage' => _yearMileageDetails(
            listing,
            data,
            language,
            outOf100,
          ),
          'risk' => [
            messages.scoreRiskRule(
              risk: '${listing.riskScore ?? (100 - sliceScore).round()}',
            ),
          ],
          _ => [
            if ((data['dealer_bikes'] as num?)?.toInt() case final bikes?)
              messages.scoreSellerFrom(bikes: '$bikes'),
          ],
        },
      ),
    );
  }

  final bonus = (data['equipment_bonus'] as num?)?.toInt() ?? 0;
  final totals = [
    ScoreBreakdownTotal(
      messages.scoreWeightedAverage,
      Formatters.decimal(weighted, language: language),
    ),
    if (bonus > 0)
      ScoreBreakdownTotal(switch (extrasText(
        data,
        key: 'valued_extras',
        language: language,
      )) {
        final extras? => messages.scoreEquipmentBonusFor(extras: extras),
        null => messages.scoreEquipmentBonus,
      }, '+$bonus'),
    if (data['capped_without_price'] == true)
      ScoreBreakdownTotal(messages.scoreCapWithoutPrice, '70'),
    if (data['capped_for_damage'] == true)
      ScoreBreakdownTotal(messages.scoreCapDamage, '79'),
    if (data['capped_for_legalisation'] == true)
      ScoreBreakdownTotal(messages.scoreCapLegalisation, '79'),
    ScoreBreakdownTotal('Deal Score', '$score', isResult: true),
  ];
  return ScoreBreakdown(rows: rows, totals: totals);
}

/// Why a slice without data doesn't count.
String _notCounted(
  String slice,
  Listing listing,
  Map<String, dynamic> data,
  AppLanguage language,
) {
  final messages = language.messages;
  switch (slice) {
    case 'price':
      final comparables = (data['market_listing_count'] as num?)?.toInt();
      return listing.askingPrice == null
          ? messages.scoreNotCountedNoPrice
          : messages.scoreNotCountedFewComparables(
              count: '${comparables ?? 0}',
            );
    case 'year_mileage':
      return messages.scoreNotCountedNoYearMileage;
    case 'risk':
      return messages.scoreNotCountedNoRisk;
  }
  return listing.sellerType == SellerType.dealer
      ? messages.scoreNotCountedSmallDealer
      : messages.scoreNotCountedPrivate;
}

/// The price against the value it was judged by (the estimate, less a
/// repair allowance or the legalisation when they apply, or a new one's
/// price for a nearly new bike), then the rule that turns it into points.
List<String> _priceDetails(
  Listing listing,
  Map<String, dynamic> data,
  AppLanguage language,
) {
  final messages = language.messages;
  num? value(String key) => data[key] as num?;
  final (reference, referenceValue, pct) = data['price_from_new'] == true
      ? (messages.scoreReferenceNew, value('new_price'), value('pct_below_new'))
      : value('legalised_value') != null
      ? (
          messages.scoreReferenceLegalised,
          value('legalised_value'),
          value('pct_below_legalised_value'),
        )
      : value('damaged_value') != null
      ? (
          messages.scoreReferenceDamaged,
          value('damaged_value'),
          value('pct_below_damaged_value'),
        )
      : (
          messages.scoreReferenceEstimate,
          value('market_price'),
          value('pct_below_market'),
        );
  return [
    if (referenceValue != null && pct != null)
      if (pct.abs() < 0.05)
        messages.scorePriceAt(
          reference: reference,
          price: Formatters.price(
            referenceValue.toDouble(),
            language: language,
          ),
        )
      else
        (pct > 0 ? messages.scorePriceBelow : messages.scorePriceAbove)(
          pct: Formatters.percent(pct.abs(), decimals: 1, language: language),
          reference: reference,
          price: Formatters.price(
            referenceValue.toDouble(),
            language: language,
          ),
        ),
    messages.scorePriceRule,
  ];
}

/// The two parts of the year/mileage slice and their shares, once the
/// breakdown carries them (scored since N.126).
List<String> _yearMileageDetails(
  Listing listing,
  Map<String, dynamic> data,
  AppLanguage language,
  String Function(num) outOf100,
) {
  final messages = language.messages;
  final mileageScore = data['mileage_score'] as num?;
  final yearScore = data['year_score'] as num?;
  final mileageShare = (data['mileage_share'] as num?)?.toDouble();
  String share(double? value) => value == null
      ? ''
      : messages.scorePartShare(
          share: Formatters.percent(value * 100, language: language),
        );
  return [
    if (mileageScore != null)
      listing.mileage == null
          ? messages.scorePartMileageHidden(
              score: outOf100(mileageScore),
              share: share(mileageShare),
            )
          : messages.scorePartMileage(
              mileage: Formatters.mileage(listing.mileage, language: language),
              score: outOf100(mileageScore),
              share: share(mileageShare),
            ),
    if (yearScore != null)
      messages.scorePartYear(
        year: '${listing.year ?? ''}',
        score: outOf100(yearScore),
        share: share(mileageShare == null ? null : 1 - mileageShare),
      ),
    if (mileageScore != null) messages.scoreMileageRule,
    if (yearScore != null) messages.scoreYearRule,
  ];
}
