import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/entities/model_market.dart';
import '../../domain/repositories/market_behaviour_repository.dart';
import '../market_behaviour_text.dart';
import '../model_market_text.dart';
import '../../../../core/localization/localizations.dart';

/// The tracked models side by side: asking prices, how fast listings leave
/// the market, price drops and depreciation. Cheapest typical price first.
class ModelMarketPage extends StatefulWidget {
  const ModelMarketPage({super.key});

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
      body: FutureBuilder<List<ModelMarket>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StateMessage(
              icon: Icons.cloud_off_outlined,
              title: context.strings.couldNotLoadModels,
              actionLabel: context.strings.retry,
              onAction: () => setState(() => _future = _load()),
            );
          }
          final models = snapshot.data;
          if (models == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (models.isEmpty) {
            return StateMessage(
              icon: Icons.two_wheeler,
              title: context.strings.noFollowedModels,
              message: context.strings.chooseModelsInMoreFollowedModels,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final model in models) _ModelCard(model: model),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                  context
                      .strings
                      .askingPricesInActiveListingsExcludingDuplicatesAnd,
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

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.model});

  final ModelMarket model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final behaviour = model.behaviour;
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
              _Line(icon: Icons.euro, text: line),
            if (behaviour != null)
              for (final line in marketLines(
                behaviour,
                language: context.language,
              ))
                _Line(icon: Icons.insights_outlined, text: line),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
