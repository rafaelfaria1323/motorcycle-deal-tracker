import 'package:flutter/material.dart';

import '../../../../core/localization/localizations.dart';
import '../../../collector_status/presentation/collection_text.dart';
import '../../../listings/presentation/widgets/icon_line.dart';
import '../../../market/domain/entities/exit_price.dart';
import '../../../market/domain/entities/market_behaviour.dart';
import '../../domain/entities/bike_condition.dart';
import '../../domain/entities/bike_value.dart';
import '../bike_value_text.dart';

/// The answer to "Calcular": the bike's value, the price to ask and the
/// trade-in, or, while [value] is null, that it waits for a collection.
class const BikeValueCard({
  required final String name,
  required final int year,
  required final BikeValue? value,
  required final MarketBehaviour? market,
  required final BikeCondition condition,
  final ExitPrice? exit,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final value = this.value;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name $year', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (value == null) ...[
              IconLine(
                icon: Icons.travel_explore,
                text: strings.bikeValueWaiting,
              ),
              IconLine(
                icon: Icons.schedule,
                text: nextCollectionText(
                  DateTime.now(),
                  language: context.language,
                ),
              ),
            ] else ...[
              for (final line in bikeValueLines(
                value,
                market,
                condition: condition,
                exit: exit,
                language: context.language,
              ))
                IconLine(icon: _icons[line.kind]!, text: line.text),
              const SizedBox(height: 8),
              Text(strings.bikeValueNote, style: muted),
            ],
          ],
        ),
      ),
    );
  }
}

const _icons = {
  BikeValueLineKind.estimate: Icons.euro,
  BikeValueLineKind.condition: Icons.tune,
  BikeValueLineKind.exit: Icons.handshake_outlined,
  BikeValueLineKind.asking: Icons.sell_outlined,
  BikeValueLineKind.time: Icons.schedule,
  BikeValueLineKind.tradeIn: Icons.store_outlined,
};
