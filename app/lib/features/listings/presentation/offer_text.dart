import 'dart:math';

import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import '../domain/entities/market_behaviour.dart';
import 'market_behaviour_text.dart';

/// What to offer for a listing: where to start and the most to pay, with
/// the reasons in words. Built from asking prices, never from sales.
class OfferSuggestion {
  const OfferSuggestion({
    required this.opening,
    required this.ceiling,
    required this.reasons,
  });

  final double opening;
  final double ceiling;
  final List<String> reasons;

  /// "Comece por 6300 € e não passe de 6700 €."
  String get headline =>
      'Comece por ${Formatters.price(opening)} e não passe de '
      '${Formatters.price(ceiling)}.';
}

/// Where the opening offer starts below the ceiling before anything else is
/// known: a rule of thumb, not measured (dealers negotiate less).
const privateMargin = 0.06;
const dealerMargin = 0.03;

/// Never suggest starting more than this far below the ceiling.
const maxMargin = 0.15;

/// Up on the site this long without a model figure counts as long.
const defaultLongListingDays = 45;

/// Prices are rounded to this many euros.
const offerStep = 50.0;

/// Null without an asking price or an estimated value (fewer than two
/// comparable listings), for a removed listing and for a repeat of another
/// listing (it has no value of its own).
///
/// [daysListed] counts from when the bike went on sale (the site's date,
/// earlier relists included), [market] is the model's behaviour (may be
/// null while it loads or when it failed).
OfferSuggestion? suggestOffer(
  Listing listing, {
  MarketBehaviour? market,
  int? daysListed,
}) {
  final price = listing.price;
  final estimate = (listing.scoreBreakdown?['market_price'] as num?)
      ?.toDouble();
  if (price == null || price <= 0 || estimate == null || estimate <= 0) {
    return null;
  }
  if (listing.isRemoved || listing.duplicateOf != null) return null;

  final reasons = <String>[];

  // The most to pay: the asking price, or the estimated value when the
  // asking price is above it.
  final double ceiling;
  if (price > estimate * 1.02) {
    ceiling = _roundDown(estimate);
    reasons.add(
      'O preço pedido está ${Formatters.percent((price / estimate - 1) * 100)} '
      'acima do valor estimado: não pague mais do que '
      '${Formatters.price(ceiling)}.',
    );
  } else {
    ceiling = _roundDown(price);
    if (price < estimate * 0.98) {
      reasons.add(
        'O preço pedido já está '
        '${Formatters.percent((1 - price / estimate) * 100)} abaixo do valor '
        'estimado (${Formatters.price(estimate)}).',
      );
    } else {
      reasons.add('O preço pedido está em linha com o valor estimado.');
    }
  }

  final dealer = listing.sellerType == SellerType.dealer;
  var margin = dealer ? dealerMargin : privateMargin;
  reasons.add(
    dealer
        ? 'Vendedor profissional: ponto de partida '
              '${Formatters.percent(dealerMargin * 100)} abaixo (os stands '
              'negociam pouco o preço).'
        : 'Vendedor particular: ponto de partida '
              '${Formatters.percent(privateMargin * 100)} abaixo.',
  );

  // Long on sale: the seller has had time to see what the market pays.
  final enoughGone =
      market != null &&
      market.goneCount >= minMarketData &&
      market.medianDaysToGone != null;
  final typicalDays = enoughGone
      ? market.medianDaysToGone!
      : defaultLongListingDays;
  if (daysListed != null && daysListed > typicalDays) {
    final veryLong = daysListed > 2 * typicalDays;
    margin += veryLong ? 0.05 : 0.03;
    reasons.add(
      'À venda há $daysListed dias, '
      '${enoughGone ? 'mais do que o típico deste modelo ($typicalDays dias)' : 'muito tempo'}: '
      'há mais margem para negociar.',
    );
  }

  final dropped = (listing.priceChange ?? 0) <= -1;
  if (dropped) {
    margin -= 0.02;
    reasons.add('O vendedor já baixou o preço: há menos margem.');
  } else if (market != null &&
      market.pricedCount >= minMarketData &&
      market.droppedCount * 3 >= market.pricedCount &&
      market.medianDropPct != null) {
    // A third or more of this model's sellers drop, by this much.
    final usual = min(market.medianDropPct! / 2, 4.0);
    margin += usual / 100;
    reasons.add(
      'Muitos vendedores deste modelo acabam por baixar o preço '
      '(descida típica ${Formatters.percent(market.medianDropPct!, decimals: 1)}).',
    );
  }

  final risk = listing.riskScore;
  if (risk != null && risk >= 50) {
    margin += 0.03;
    reasons.add(
      'O risco é elevado: peça para ver o que falta e use-o para negociar.',
    );
  }

  if (ceiling < offerStep) return null;
  // At least 1 % (a dealer's 3 % less an earlier drop), so the opening is
  // always below the ceiling.
  margin = margin.clamp(0.01, maxMargin);
  final opening = _roundDown(ceiling * (1 - margin));
  return OfferSuggestion(opening: opening, ceiling: ceiling, reasons: reasons);
}

/// Days the bike has been on sale: from the earliest relisted date, the
/// site's publication date or, without one, the first time we saw it.
int? daysOnSale(Listing listing, {DateTime? now}) {
  final since =
      listing.relistedSince ?? listing.publishedAt ?? listing.firstSeenAt;
  if (since == null) return null;
  return max(0, (now ?? DateTime.now()).difference(since).inDays);
}

double _roundDown(double value) => (value / offerStep).floor() * offerStep;
