import '../../../app/di/injection.dart';
import '../../market/domain/entities/market_behaviour.dart';
import '../../market/domain/repositories/market_behaviour_repository.dart';
import '../domain/entities/listing.dart';
import '../domain/repositories/listings_repository.dart';

/// What the offer and its arguments need beyond the ad: the model's
/// market behaviour and the cheaper live ads like it. Either is left
/// empty when it can't be read; the suggestion still works without.
typedef OfferContext = (MarketBehaviour?, List<Listing>);

final _loaded = Expando<Future<OfferContext>>();

/// [OfferContext] of [listing], asked for once per loaded listing: "Quanto
/// oferecer" and "Relatório do anúncio" share the answer.
Future<OfferContext> offerContextOf(Listing listing) =>
    _loaded[listing] ??= _load(listing);

Future<OfferContext> _load(Listing listing) async {
  final id = listing.motorcycleId;
  final market = id == null
      ? Future<MarketBehaviour?>.value()
      : getIt<MarketBehaviourRepository>()
            .getForModel(id)
            .then<MarketBehaviour?>((m) => m, onError: (Object _) => null);
  final cheaper = getIt<ListingsRepository>()
      .getCheaperSimilar(listing)
      .then((l) => l, onError: (Object _) => const <Listing>[]);
  return (await market, await cheaper);
}
