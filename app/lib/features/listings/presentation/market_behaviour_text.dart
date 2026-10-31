import 'dart:math';

import '../../../core/formatting/formatters.dart';
import '../domain/entities/market_behaviour.dart';
import '../../../core/localization/localizations.dart';

/// Below this many listings a figure is not shown as a fact.
const minMarketData = 5;

/// Listings a model needs before its own depreciation is fitted (the same
/// threshold as the model_depreciation view).
const minDepreciationData = 30;

/// [daysListed] counts from the site's publication date, or from the day
/// the collector first saw the listing when the site gave none
/// ([firstSeenOnly]); then the line says so instead of "publicado".
List<String> marketLines(
  MarketBehaviour m, {
  int? daysListed,
  bool firstSeenOnly = false,
  AppLanguage language = .portuguese,
}) {
  final lines = <String>[
    language.messages.activeOfModel(liveCount: m.liveCount),
  ];

  final toGone = m.medianDaysToGone;
  final enoughGone = m.goneCount >= minMarketData && toGone != null;
  if (enoughGone) {
    lines.add(
      language.messages.typicalTimeToGone(
        toGone: (toGone).toString(),
        goneCount: m.goneCount.toString(),
      ),
    );
  } else {
    lines.add(language.messages.timeToGoneFewData(goneCount: m.goneCount));
  }

  if (m.pricedCount >= minMarketData) {
    if (m.droppedCount == 0) {
      lines.add(language.messages.noSellerHasReducedPriceSinceWeStarted);
    } else {
      final share = (m.droppedCount * 100 / m.pricedCount).round();
      final drop = m.medianDropPct;
      lines.add(
        drop == null
            ? language.messages.ofSellersReducedTheirPrice(
                percent: Formatters.percent(share, language: language),
              )
            : language.messages.ofSellersReducedTheirPriceTypicalDrop(
                percent: Formatters.percent(share, language: language),
                percent2: Formatters.percent(
                  drop,
                  decimals: 1,
                  language: language,
                ),
              ),
      );
    }
  }

  final depreciation = m.depreciation;
  if (depreciation != null) {
    lines.add(depreciationLine(depreciation, language: language));
  }

  if (daysListed != null) {
    lines.add(switch ((daysListed <= 0, firstSeenOnly)) {
      (true, false) => language.messages.thisListingWasPublishedToday,
      (true, true) => language.messages.firstSeenToday,
      (false, false) => language.messages.publishedForDays(
        daysListed: daysListed,
      ),
      (false, true) => language.messages.firstSeenAgo(daysListed: daysListed),
    });
    if (enoughGone && daysListed > 2 * toGone) {
      lines.add(language.messages.forSaleForMoreThanTwiceUsualTime);
    }
  }
  return lines;
}

/// The yearly and per-10 000 km loss in value, as percentages of the price.
String depreciationLine(Depreciation d, {AppLanguage language = .portuguese}) {
  String pct(double rate) => Formatters.percent(
    (1 - exp(-rate)) * 100,
    decimals: 1,
    language: language,
  );
  final rates = language.messages.depreciationRates(
    perYear: pct(d.perYear),
    per10000Km: pct(d.per1000Km * 10),
  );

  return d.isFitted
      ? language.messages.depreciationForThisModelListings(
          rates: rates,
          sampleCount: d.sampleCount.toString(),
        )
      : language.messages.depreciationGeneralRule(
          sampleCount: d.sampleCount.toString(),
          minDepreciationData: (minDepreciationData).toString(),
          rates: rates,
        );
}
