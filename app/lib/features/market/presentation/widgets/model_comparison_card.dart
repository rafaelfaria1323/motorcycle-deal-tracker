import 'package:material_ui/material_ui.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../compare/presentation/widgets/compare_row_view.dart';
import '../../../valuation/domain/entities/bike_value.dart';
import '../../../valuation/domain/entities/fuel_price.dart';
import '../../../valuation/domain/entities/ownership_settings.dart';
import '../../../valuation/domain/repositories/fuel_price_repository.dart';
import '../../../valuation/domain/repositories/ownership_settings_repository.dart';
import '../../domain/entities/model_market.dart';
import '../../domain/repositories/market_behaviour_repository.dart';
import '../model_comparison_text.dart';

/// Two of the tracked models side by side (N.81): pick them, then their
/// prices, the value of each recent year, how fast they lose value and
/// sell, and the yearly cost of owning each one's typical bike.
class const ModelComparisonCard({
  required final List<ModelMarket> models,
  super.key,
}) extends StatefulWidget {
  @override
  State<ModelComparisonCard> createState() => _ModelComparisonCardState();
}

typedef _Owner = ({OwnershipSettings settings, FuelPrice? fuel});
typedef _Compared = ({OwnershipSettings settings, List<ComparedModel> models});

class _ModelComparisonCardState extends State<ModelComparisonCard> {
  late String _first = widget.models[0].motorcycleId;
  late String _second = widget.models[1].motorcycleId;
  final DateTime _now = DateTime.now();

  // The owner's figures, read once; each can fail on its own.
  late final Future<_Owner> _owner = () async {
    final (settings, fuel) = await (
      getIt<OwnershipSettingsRepository>().get().catchError(
        (Object _) => const OwnershipSettings(),
      ),
      getIt<FuelPriceRepository>().latest().catchError((Object _) => null),
    ).wait;
    return (settings: settings, fuel: fuel);
  }();

  // Each model's values by year, read once per model.
  final Map<String, Future<Map<int, BikeValue>>> _values = {};

  Future<Map<int, BikeValue>> _valuesOf(String id) =>
      _values.putIfAbsent(id, () async {
        final repository = getIt<MarketBehaviourRepository>();
        final years = comparisonYears(_now);
        final found = await Future.wait([
          for (final year in years)
            repository
                .getBikeValue(
                  id,
                  year: year,
                  mileage: comparisonMileage(year, _now),
                )
                .then<BikeValue?>((v) => v)
                .catchError((Object _) => null),
        ]);
        return {for (final (i, value) in found.indexed) years[i]: ?value};
      });

  @override
  void didUpdateWidget(ModelComparisonCard old) {
    super.didUpdateWidget(old);
    // A reload can bring other models: keep the picks that are still there.
    final ids = {for (final m in widget.models) m.motorcycleId};
    if (ids.contains(_first) && ids.contains(_second)) return;
    _first = widget.models[0].motorcycleId;
    _second = widget.models[1].motorcycleId;
    _compared = _load();
  }

  ModelMarket _model(String id) =>
      widget.models.firstWhere((m) => m.motorcycleId == id);

  late Future<_Compared> _compared = _load();

  Future<_Compared> _load() async {
    final (owner, first, second) = await (
      _owner,
      _valuesOf(_first),
      _valuesOf(_second),
    ).wait;
    return (
      settings: owner.settings,
      models: [
        for (final (id, values) in [(_first, first), (_second, second)])
          (
            model: _model(id),
            values: values,
            cost: typicalOwnershipCost(
              _model(id),
              settings: owner.settings,
              fuelPrice: owner.fuel,
            ),
          ),
      ],
    );
  }

  Widget _picker(String label, String value, ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final m in widget.models)
            DropdownMenuItem(
              value: m.motorcycleId,
              child: Text(m.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (id) {
          if (id == null) return;
          setState(() {
            onChanged(id);
            _compared = _load();
          });
        },
      );

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        title: strings.modelCompareTitle,
        children: [
          Row(
            children: [
              Expanded(
                child: _picker(
                  strings.modelCompareFirst,
                  _first,
                  (id) => _first = id,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _picker(
                  strings.modelCompareSecond,
                  _second,
                  (id) => _second = id,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FutureBuilder<_Compared>(
            future: _compared,
            builder: (context, snapshot) {
              final compared = snapshot.data;
              if (compared == null ||
                  snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final row in modelComparisonRows(
                    compared.models,
                    now: _now,
                    language: context.language,
                  )) ...[const Divider(height: 16), CompareRowView(row)],
                  const SizedBox(height: 12),
                  Text(
                    modelComparisonNote(
                      compared.settings,
                      language: context.language,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
