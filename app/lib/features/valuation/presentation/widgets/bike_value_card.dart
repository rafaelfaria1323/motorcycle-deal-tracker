import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/formatting/formatters.dart';
import '../../../../core/localization/localizations.dart';
import '../../../collector_status/presentation/collection_text.dart';
import '../../../listings/presentation/widgets/icon_line.dart';
import '../../../market/domain/entities/exit_price.dart';
import '../../../market/domain/entities/market_behaviour.dart';
import '../../domain/entities/bike_condition.dart';
import '../../domain/entities/bike_value.dart';
import '../bike_value_text.dart';

/// The answer to "Calcular", after the Stitch design (UI.5): the price to
/// ask, the market value and the trade-in as three tiles, where most
/// comparable listings sit, what the model's gone ads left the market at,
/// then how the value was reached (the condition's factors in euros, the
/// time to sell, the asking room and the trade-in's rule). While [value]
/// is null, that it waits for a collection.
class const BikeValueCard({
  required final String name,
  required final int year,
  required final BikeValue? value,
  required final MarketBehaviour? market,
  required final BikeCondition condition,
  final ExitPrice? exit,
  super.key,
}) extends StatelessWidget {
  /// The lines told under "Como chegámos ao valor"; the estimate and the
  /// condition are in the tiles and the factors, the exit price in its box.
  static const _reasons = {
    BikeValueLineKind.time,
    BikeValueLineKind.asking,
    BikeValueLineKind.tradeIn,
  };

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final language = context.language;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final value = this.value;
    final figures = value == null
        ? null
        : bikeValueFigures(value, market, condition: condition);
    final lines = value == null
        ? const <BikeValueLine>[]
        : bikeValueLines(
            value,
            market,
            condition: condition,
            exit: exit,
            language: language,
          );
    String? lineOf(BikeValueLineKind kind) =>
        lines.where((line) => line.kind == kind).firstOrNull?.text;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (value == null) ...[
              Text('$name $year', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              IconLine(
                icon: Icons.travel_explore,
                text: strings.bikeValueWaiting,
              ),
              IconLine(
                icon: Icons.schedule,
                text: nextCollectionText(DateTime.now(), language: language),
              ),
            ] else if (figures == null) ...[
              Text('$name $year', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final line in lines)
                IconLine(icon: Icons.euro, text: line.text),
            ] else ...[
              Text(
                strings.bikeValueMarketEstimate,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                strings.bikeValueBasedOn(
                  name: '$name $year',
                  count: value.comparableCount,
                ),
                style: muted,
              ),
              const SizedBox(height: 16),
              _Tiles(figures: figures),
              const SizedBox(height: 20),
              _Range(figures: figures),
              if (lineOf(BikeValueLineKind.exit) case final exitLine?) ...[
                const SizedBox(height: 16),
                _Note(icon: Icons.trending_down, text: exitLine),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.bikeValueReasoning,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (figures.factors.isNotEmpty) _Factors(figures: figures),
              for (final line in lines)
                if (_reasons.contains(line.kind))
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
  BikeValueLineKind.time: Icons.bolt_outlined,
  BikeValueLineKind.asking: Icons.sell_outlined,
  BikeValueLineKind.tradeIn: Icons.store_outlined,
};

/// Asking price, market value (in the accent) and trade-in, side by side.
class const _Tiles({required final BikeValueFigures figures})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final language = context.language;
    String price(double amount) => Formatters.price(amount, language: language);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Tile(
              label: strings.bikeValueTileAsking,
              figure: price(figures.asking),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Tile(
              label: strings.bikeValueTileValue,
              figure: price(figures.estimate),
              strong: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Tile(
              label: strings.bikeValueTileTradeIn,
              figure: price(figures.tradeIn),
            ),
          ),
        ],
      ),
    );
  }
}

class const _Tile({
  required final String label,
  required final String figure,
  final bool strong = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = strong ? scheme.onPrimary : scheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: strong ? scheme.primary : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: strong ? null : Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTheme.groupLabel(context)?.copyWith(
                color: strong ? scheme.onPrimary : null,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                figure,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: foreground,
                  fontFeatures: AppTheme.tabularFigures,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The middle half of the comparable listings as a bar, the value marked
/// on it, with both ends' prices under it.
class const _Range({required final BikeValueFigures figures})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = context.language;
    final span = figures.high - figures.low;
    final at = span <= 0
        ? 0.5
        : ((figures.estimate - figures.low) / span).clamp(0.0, 1.0);
    final ends = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: AppTheme.tabularFigures,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.strings.bikeValueRange.toUpperCase(),
          style: AppTheme.groupLabel(context),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 14,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).positive,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                PositionedDirectional(
                  start: (constraints.maxWidth - 4) * at,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurface,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              Formatters.price(figures.low, language: language),
              style: ends,
            ),
            const Spacer(),
            Text(
              Formatters.price(figures.high, language: language),
              style: ends,
            ),
          ],
        ),
      ],
    );
  }
}

/// A line in a tinted box (what the model's gone ads left the market at).
class const _Note({required final IconData icon, required final String text})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.of(context).positive),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

/// The condition's factors, each with what it moves the value by in euros.
class const _Factors({required final BikeValueFigures figures})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final language = context.language;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.strings.bikeValueFactors.toUpperCase(),
                style: AppTheme.groupLabel(context),
              ),
              const SizedBox(height: 6),
              for (final (:factor, :amount) in figures.factors)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          conditionFactorLabel(factor, language: language),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        signedPrice(amount, language: language),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: AppTheme.tabularFigures,
                          color: amount >= 0
                              ? colors.positive
                              : colors.negative,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
