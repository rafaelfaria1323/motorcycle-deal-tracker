import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import '../domain/entities/bike_value.dart';
import '../domain/entities/market_behaviour.dart';
import 'market_behaviour_text.dart';
import 'offer_text.dart';

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

enum BikeValueLineKind { estimate, asking, time, tradeIn }

typedef BikeValueLine = ({BikeValueLineKind kind, String text});

/// The share above the value to ask: the model's typical price drop when
/// enough sellers' prices are known, else [defaultAskingRoom].
double askingRoom(MarketBehaviour? market) => askingRoomFromModel(market)
    ? (market!.medianDropPct! / 100).clamp(minAskingRoom, maxAskingRoom)
    : defaultAskingRoom;

/// What to say about a bike's value: the estimate and its range, the price
/// to ask, how long the model takes to sell and a dealer's trade-in. Fewer
/// than [minComparables] listings give only a line saying so.
List<BikeValueLine> bikeValueLines(
  BikeValue value,
  MarketBehaviour? market, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  final messages = language.messages;
  final estimate = value.estimate;
  if (estimate == null || value.comparableCount < minComparables) {
    return [
      (
        kind: BikeValueLineKind.estimate,
        text: messages.bikeValueFewData(count: value.comparableCount),
      ),
    ];
  }
  String price(double amount) => Formatters.price(amount, language: language);

  final room = askingRoom(market);
  final asking = price(_roundDown(estimate * (1 + room)));
  final roomText = Formatters.percent(room * 100, language: language);
  final gone = market?.goneCount ?? 0;
  final toGone = market?.medianDaysToGone;

  return [
    (
      kind: BikeValueLineKind.estimate,
      text: messages.bikeValueEstimate(
        price: price(estimate),
        low: price(value.low ?? estimate),
        high: price(value.high ?? estimate),
        count: value.comparableCount,
      ),
    ),
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

/// Whether [askingRoom] comes from the model's own price drops.
bool askingRoomFromModel(MarketBehaviour? market) =>
    market != null &&
    market.pricedCount >= minMarketData &&
    market.medianDropPct != null;

double _roundDown(double value) => (value / offerStep).floor() * offerStep;
