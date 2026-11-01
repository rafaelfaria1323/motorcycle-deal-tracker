import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import '../domain/entities/bike_condition.dart';
import '../domain/entities/bike_value.dart';
import '../domain/entities/bike_value_request.dart';
import '../../market/domain/entities/exit_price.dart';
import '../../market/domain/entities/market_behaviour.dart';
import '../../market/presentation/exit_price_text.dart';
import '../../market/presentation/market_behaviour_text.dart';
import '../../listings/presentation/offer_text.dart';

/// Room left above the value for the buyer to bargain, when the model's
/// own price drops don't say (a typical first offer of 3-6 % below).
const defaultAskingRoom = 0.05;

/// The model's typical drop is kept within these, so one odd seller
/// doesn't set the asking price.
const minAskingRoom = 0.03;
const maxAskingRoom = 0.08;

/// A dealer's trade-in, as a share of the market value: a rule of thumb,
/// the dealer has to resell with a margin and a warranty.
const tradeInShare = 0.80;

enum BikeValueLineKind { estimate, condition, exit, asking, time, tradeIn }

typedef BikeValueLine = ({BikeValueLineKind kind, String text});

/// The share above the value to ask: the model's typical price drop when
/// enough sellers' prices are known, else [defaultAskingRoom].
double askingRoom(MarketBehaviour? market) => askingRoomFromModel(market)
    ? (market!.medianDropPct! / 100).clamp(minAskingRoom, maxAskingRoom)
    : defaultAskingRoom;

/// What moves the value of a bike against the comparable listings (asking
/// prices of bikes as advertised, mostly without damage), as rules of
/// thumb in step with the offer's: an accident takes 15 %, a fall with
/// cosmetic damage only 5 % (the offer's damage and scratches); a first
/// owner adds 3 %, three or more owners take 5 % (the risk's signal); no
/// service book takes 5 %; a factory warranty still running adds 3 %.
enum ConditionFactor {
  accident(-0.15),
  dropped(-0.05),
  firstOwner(0.03),
  manyOwners(-0.05),
  noServiceBook(-0.05),
  warranty(0.03);

  const ConditionFactor(this.share);

  /// The change to the value, as a share (-0.15 = 15 % less).
  final double share;
}

/// The factors [condition] brings, in [ConditionFactor]'s order; what is
/// not known or usual (two owners, a service book) brings none.
List<ConditionFactor> conditionFactors(BikeCondition condition) => [
  if (condition.damage == .accident) ConditionFactor.accident,
  if (condition.damage == .dropped) ConditionFactor.dropped,
  if (condition.owners == .one) ConditionFactor.firstOwner,
  if (condition.owners == .threeOrMore) ConditionFactor.manyOwners,
  if (condition.serviceBook == .no) ConditionFactor.noServiceBook,
  if (condition.warranty) ConditionFactor.warranty,
];

/// The factors' total change, as a share (between -25 % and +6 %).
double conditionShare(BikeCondition condition) =>
    conditionFactors(condition).fold<double>(0, (sum, f) => sum + f.share);

/// The value adjusted to [condition]; null below [minComparables]
/// listings.
double? conditionEstimate(
  BikeValue value, [
  BikeCondition condition = const BikeCondition(),
]) {
  final estimate = value.estimate;
  if (estimate == null || value.comparableCount < minComparables) return null;
  return estimate * (1 + conditionShare(condition));
}

/// What to say about a bike's value: the estimate and its range (adjusted
/// to [condition], with a line saying how), what the model's gone ads left
/// the market at ([exit], adjusted the same way; left out with too few),
/// the price to ask, how long the model takes to sell and a dealer's
/// trade-in. Fewer than
/// [minComparables] listings give only a line saying so.
List<BikeValueLine> bikeValueLines(
  BikeValue value,
  MarketBehaviour? market, {
  BikeCondition condition = const BikeCondition(),
  ExitPrice? exit,
  AppLanguage language = .portuguese,
}) {
  final messages = language.messages;
  final estimate = conditionEstimate(value, condition);
  if (estimate == null) {
    return [
      (
        kind: BikeValueLineKind.estimate,
        text: messages.bikeValueFewData(count: value.comparableCount),
      ),
    ];
  }
  String price(double amount) => Formatters.price(amount, language: language);
  final factors = conditionFactors(condition);
  final adjust = 1 + conditionShare(condition);
  final comparablesEstimate = value.estimate!;

  final room = askingRoom(market);
  final asking = price(_roundDown(estimate * (1 + room)));
  final roomText = Formatters.percent(room * 100, language: language);
  final gone = market?.goneCount ?? 0;
  final toGone = market?.medianDaysToGone;
  final exitLine = exit == null
      ? null
      : exitPriceLine(exit, adjust: adjust, language: language);

  return [
    (
      kind: BikeValueLineKind.estimate,
      text: messages.bikeValueEstimate(
        price: price(estimate),
        low: price((value.low ?? comparablesEstimate) * adjust),
        high: price((value.high ?? comparablesEstimate) * adjust),
        count: value.comparableCount,
      ),
    ),
    if (factors.isNotEmpty)
      (
        kind: BikeValueLineKind.condition,
        text: messages.bikeValueConditionLine(
          reasons: [
            for (final f in factors)
              '${_conditionLabel(f, messages)} '
                  '${_signedPercent(f.share, language)}',
          ].join(', '),
          total: _signedPercent(adjust - 1, language),
        ),
      ),
    if (exitLine != null) (kind: BikeValueLineKind.exit, text: exitLine),
    (
      kind: BikeValueLineKind.asking,
      text: askingRoomFromModel(market)
          ? messages.bikeValueAskModel(price: asking, percent: roomText)
          : messages.bikeValueAskDefault(price: asking, percent: roomText),
    ),
    (
      kind: BikeValueLineKind.time,
      text: gone >= minMarketData && toGone != null
          ? messages.typicalTimeToGone(
              toGone: toGone.toString(),
              goneCount: gone.toString(),
            )
          : messages.timeToGoneFewData(goneCount: gone),
    ),
    (
      kind: BikeValueLineKind.tradeIn,
      text: messages.bikeValueTradeIn(
        price: price(_roundDown(estimate * tradeInShare)),
      ),
    ),
  ];
}

String _conditionLabel(ConditionFactor factor, AppLocalizations messages) =>
    switch (factor) {
      ConditionFactor.accident => messages.bikeValueFactorAccident,
      ConditionFactor.dropped => messages.bikeValueFactorDropped,
      ConditionFactor.firstOwner => messages.bikeValueFactorFirstOwner,
      ConditionFactor.manyOwners => messages.bikeValueFactorManyOwners,
      ConditionFactor.noServiceBook => messages.bikeValueFactorNoServiceBook,
      ConditionFactor.warranty => messages.bikeValueFactorWarranty,
    };

/// "+3 %", "−15 %", "0 %".
String _signedPercent(double share, AppLanguage language) {
  final percent = (share * 100).round();
  final text = Formatters.percent(percent.abs(), language: language);
  return percent > 0 ? '+$text' : (percent < 0 ? '−$text' : text);
}

/// Whether [askingRoom] comes from the model's own price drops.
bool askingRoomFromModel(MarketBehaviour? market) =>
    market != null &&
    market.pricedCount >= minMarketData &&
    market.medianDropPct != null;

double _roundDown(double value) => (value / offerStep).floor() * offerStep;

/// A request in "Os seus pedidos": "2019 · 30 000 km · À espera da
/// recolha" (the mileage left out when not given).
String bikeValueRequestLine(
  BikeValueRequest request, {
  AppLanguage language = .portuguese,
}) {
  final messages = language.messages;
  return [
    '${request.year}',
    if (request.mileage != null)
      Formatters.mileage(request.mileage, language: language),
    request.waiting
        ? messages.bikeValueRequestWaiting
        : messages.bikeValueRequestReady,
  ].join(' · ');
}
