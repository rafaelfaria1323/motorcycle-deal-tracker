import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../listings/domain/entities/listing.dart';
import '../../domain/entities/exit_price.dart';
import '../../domain/entities/gone_deal.dart';
import '../../domain/entities/market_behaviour.dart';
import '../../domain/repositories/market_behaviour_repository.dart';
import '../market_behaviour_text.dart';
import '../../../listings/presentation/price_position_text.dart';
import '../exit_price_text.dart';
import '../gone_deals_text.dart';
import '../time_to_sale_text.dart';
import '../../../listings/presentation/widgets/price_position_strip.dart';
import '../../../../core/localization/localizations.dart';

typedef _Loaded = (
  MarketBehaviour?,
  List<double>,
  TimeToSale?,
  ExitPrice?,
  List<GoneDeal>,
);

class const MarketBehaviourSection({required final Listing listing, super.key})
    extends StatefulWidget {
  @override
  State<MarketBehaviourSection> createState() => _MarketBehaviourSectionState();
}

class _MarketBehaviourSectionState extends State<MarketBehaviourSection> {
  Future<_Loaded>? _future;

  @override
  void initState() {
    super.initState();
    final id = widget.listing.motorcycleId;
    if (id != null) _future = _load(id);
  }

  Future<_Loaded> _load(String motorcycleId) async {
    final repository = getIt<MarketBehaviourRepository>();
    final listing = widget.listing;
    final (market, prices, timeToSale, exit, gone) = await (
      repository.getForModel(motorcycleId),
      // The comparison, the time to sale and the exit price are extra:
      // without them the rest still shows.
      repository
          .getLivePrices(motorcycleId)
          .catchError((Object _) => <String, double>{}),
      repository
          .getTimeToSale(listing.id)
          .then<TimeToSale?>((t) => t, onError: (Object _) => null),
      repository
          .getExitPrice(
            motorcycleId,
            year: listing.year,
            mileage: listing.mileage,
            except: listing.id,
          )
          .then<ExitPrice?>((e) => e, onError: (Object _) => null),
      repository
          .getGoneDeals(motorcycleId)
          .catchError((Object _) => const <GoneDeal>[]),
    ).wait;
    final others = [
      for (final MapEntry(:key, :value) in prices.entries)
        // Neither this listing nor the one it repeats.
        if (key != listing.id && key != listing.duplicateOf) value,
    ];
    // Neither this listing nor the one it repeats.
    final goneDeals = [
      for (final deal in gone)
        if (deal.listingId != listing.id &&
            deal.listingId != listing.duplicateOf)
          deal,
    ];
    return (market, others, timeToSale, exit, goneDeals);
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<_Loaded>(
      future: future,
      builder: (context, snapshot) {
        final (market, others, timeToSale, exit, gone) =
            snapshot.data ??
            (null, const <double>[], null, null, const <GoneDeal>[]);
        // Secondary information: hide it while loading or on any error.
        if (market == null) return const SizedBox.shrink();

        // A placeholder price ("1 €") has no place among real ones.
        final price = widget.listing.askingPrice;
        final position = pricePosition(price, others);
        final priceLine = pricePositionLine(
          price,
          others,
          language: context.language,
        );

        final since = widget.listing.publishedAt ?? widget.listing.firstSeenAt;
        final days = since == null
            ? null
            : DateTime.now().difference(since).inDays;

        final timeToSaleText = timeToSale == null
            ? null
            : timeToSaleLine(
                timeToSale,
                live: widget.listing.isLive,
                language: context.language,
              );

        final exitLine = exit == null
            ? null
            : [
                exitPriceLine(exit, language: context.language),
                exitPriceComparison(exit, price, language: context.language),
              ].nonNulls.join(' ');

        return SectionCard(
          title: context.strings.thisModelSMarket,
          children: [
            if (priceLine != null) _Line(priceLine),
            if (position != null) ...[
              const SizedBox(height: 4),
              PricePositionStrip(position: position),
              const SizedBox(height: 8),
            ],
            if (exitLine != null && exitLine.isNotEmpty) _Line(exitLine),
            for (final line in marketLines(
              market,
              daysListed: days,
              firstSeenOnly: widget.listing.publishedAt == null,
              language: context.language,
            ))
              _Line(line),
            if (timeToSaleText != null) _Line(timeToSaleText),
            if (goneDealsLine(gone, language: context.language)
                case final goneLine?) ...[
              _Line(goneLine),
              for (final deal in fastGoneDeals(gone)) _GoneDealRow(deal),
            ],
          ],
        );
      },
    );
  }
}

class const _Line(final String text) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      BulletLine(text, icon: Icons.insights_outlined);
}

/// A good deal that likely sold: opens its ad (N.68).
class const _GoneDealRow(final GoneDeal deal) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push(
        AppRoutes.listingDetail(deal.listingId),
        extra: AppRoutes.fromList,
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 28),
        child: BulletLine(
          goneDealText(deal, language: context.language),
          icon: Icons.bolt_outlined,
        ),
      ),
    );
  }
}
