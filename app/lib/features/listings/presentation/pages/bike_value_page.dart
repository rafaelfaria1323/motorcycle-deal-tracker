import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/entities/bike_value.dart';
import '../../domain/entities/model_market.dart';
import '../../domain/repositories/market_behaviour_repository.dart';
import '../bike_value_text.dart';
import '../widgets/icon_line.dart';
import '../widgets/tracked_models_builder.dart';

/// "Quanto vale a minha mota": the market value of a bike of one of the
/// followed models, the price to ask for it and a dealer's trade-in.
class BikeValuePage extends StatefulWidget {
  const BikeValuePage({super.key});

  /// The oldest year the form takes.
  static const firstYear = 1980;

  @override
  State<BikeValuePage> createState() => _BikeValuePageState();
}

class _BikeValuePageState extends State<BikeValuePage> {
  late Future<List<ModelMarket>> _models = _loadModels();
  final _form = GlobalKey<FormState>();
  final _year = TextEditingController();
  final _mileage = TextEditingController();
  String? _motorcycleId;

  /// The model asked about and its value, once "Calcular" was pressed.
  ModelMarket? _asked;
  Future<BikeValue>? _value;

  Future<List<ModelMarket>> _loadModels() async {
    final models = await getIt<MarketBehaviourRepository>().getTrackedModels();
    return [...models]..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  void dispose() {
    _year.dispose();
    _mileage.dispose();
    super.dispose();
  }

  int get _lastYear => DateTime.now().year + 1;

  /// The mileage as typed, with thousands separators allowed.
  int? _mileageValue() {
    final digits = _mileage.text.replaceAll(RegExp(r'[\s.]'), '');
    return RegExp(r'^\d+$').hasMatch(digits) ? int.parse(digits) : null;
  }

  void _calculate(List<ModelMarket> models) {
    if (!_form.currentState!.validate()) return;
    final model = models.firstWhere((m) => m.motorcycleId == _motorcycleId);
    setState(() {
      _asked = model;
      _value = getIt<MarketBehaviourRepository>().getBikeValue(
        model.motorcycleId,
        year: int.parse(_year.text.trim()),
        mileage: _mileage.text.trim().isEmpty ? null : _mileageValue(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: Text(context.strings.bikeValueTitle),
      ),
      body: TrackedModelsBuilder(
        future: _models,
        onRetry: () => setState(() => _models = _loadModels()),
        builder: (context, models) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(context.strings.bikeValueIntro),
              const SizedBox(height: 16),
              _formFields(context, models),
              const SizedBox(height: 16),
              if (_value != null) _result(context, models),
            ],
          );
        },
      ),
    );
  }

  Widget _formFields(BuildContext context, List<ModelMarket> models) {
    final strings = context.strings;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _motorcycleId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: strings.model,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final m in models)
                DropdownMenuItem(value: m.motorcycleId, child: Text(m.name)),
            ],
            validator: (value) =>
                value == null ? strings.bikeValueChooseModel : null,
            onChanged: (value) => setState(() => _motorcycleId = value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _year,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: strings.bikeValueYear,
              border: const OutlineInputBorder(),
            ),
            validator: (text) {
              final year = int.tryParse(text?.trim() ?? '');
              return year == null ||
                      year < BikeValuePage.firstYear ||
                      year > _lastYear
                  ? strings.bikeValueYearInvalid(
                      first: BikeValuePage.firstYear,
                      last: _lastYear,
                    )
                  : null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _mileage,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: strings.bikeValueMileage,
              border: const OutlineInputBorder(),
            ),
            validator: (text) =>
                (text?.trim() ?? '').isEmpty || _mileageValue() != null
                ? null
                : strings.bikeValueMileageInvalid,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _calculate(models),
            icon: const Icon(Icons.calculate_outlined),
            label: Text(strings.bikeValueCalculate),
          ),
        ],
      ),
    );
  }

  Widget _result(BuildContext context, List<ModelMarket> models) {
    final model = _asked!;
    return FutureBuilder<BikeValue>(
      future: _value,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StateMessage(
            icon: Icons.cloud_off_outlined,
            title: context.strings.bikeValueCouldNotCalculate,
            actionLabel: context.strings.retry,
            onAction: () => _calculate(models),
          );
        }
        final value = snapshot.data;
        if (value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final theme = Theme.of(context);
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(model.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final line in bikeValueLines(
                  value,
                  model.behaviour,
                  language: context.language,
                ))
                  IconLine(icon: _icons[line.kind]!, text: line.text),
                const SizedBox(height: 8),
                Text(
                  context.strings.bikeValueNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

const _icons = {
  BikeValueLineKind.estimate: Icons.euro,
  BikeValueLineKind.asking: Icons.sell_outlined,
  BikeValueLineKind.time: Icons.schedule,
  BikeValueLineKind.tradeIn: Icons.store_outlined,
};
