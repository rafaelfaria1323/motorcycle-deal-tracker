import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../domain/entities/model_market.dart';
import '../../domain/repositories/market_behaviour_repository.dart';
import '../market_behaviour_text.dart';
import '../model_market_text.dart';
import '../widgets/icon_line.dart';
import '../widgets/tracked_models_builder.dart';
import '../widgets/price_trend_sparkline.dart';
import '../../../../core/localization/localizations.dart';

/// The tracked models side by side: asking prices, how fast listings leave
/// the market, price drops and depreciation. Cheapest typical price first.
class const ModelMarketPage({super.key}) extends StatefulWidget {
  @override
  State<ModelMarketPage> createState() => _ModelMarketPageState();
}

class _ModelMarketPageState extends State<ModelMarketPage> {
  late Future<List<ModelMarket>> _future = _load();

  Future<List<ModelMarket>> _load() async => byMedianPrice(
    await getIt<MarketBehaviourRepository>().getTrackedModels(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: Text(context.strings.compareModels),
      ),
      body: TrackedModelsBuilder(
        future: _future,
        onRetry: () => setState(() => _future = _load()),
        builder: (context, models) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final model in models) _ModelCard(model: model),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                  context.strings.marketPricesNote,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class const _ModelCard({required final ModelMarket model})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final behaviour = model.behaviour;
    final trend = trendWeeksWithData(model.trend);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(model.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final line in priceSpreadLines(
              model.prices,
              language: context.language,
            ))
              IconLine(icon: Icons.euro, text: line),
            IconLine(
              icon: Icons.show_chart,
              text: priceTrendLine(model.trend, language: context.language),
            ),
            if (trend.length >= 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 4, 0, 6),
                child: PriceTrendSparkline(weeks: trend),
              ),
            if (behaviour != null)
              for (final line in marketLines(
                behaviour,
                language: context.language,
              ))
                IconLine(icon: Icons.insights_outlined, text: line),
          ],
        ),
      ),
    );
  }
}
