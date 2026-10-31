import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/auth/session_cubit.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../../../core/widgets/state_message.dart';
import '../../../collector_status/presentation/collection_text.dart';
import '../../domain/entities/bike_condition.dart';
import '../../domain/entities/bike_value.dart';
import '../../domain/entities/bike_value_request.dart';
import '../../../market/domain/entities/market_behaviour.dart';
import '../../../market/domain/entities/model_market.dart';
import '../../../listings/domain/repositories/catalog_repository.dart';
import '../../../market/domain/repositories/market_behaviour_repository.dart';
import '../bike_value_text.dart';
import '../../../listings/presentation/widgets/add_model_sheet.dart';
import '../../../listings/presentation/widgets/icon_line.dart';
import '../widgets/import_cost_card.dart';
import '../../../listings/presentation/widgets/tracked_models_builder.dart';

/// "Quanto vale a minha mota": the market value of a bike, the price to
/// ask for it and a dealer's trade-in. Anonymous sessions value the
/// collected models; accounts value any make and model: one nobody
/// collects yet is asked for, collected at the next collection, and
/// answered with a notification ([requestId] opens that answer).
/// With [importing] ("Comprar no estrangeiro", `/import`) the same value
/// is what a bike seen abroad is weighed against ([ImportCostCard], shown
/// first).
class const BikeValuePage({
  /// The request to show (`/worth?request=<id>`, from the notification).
  final String? requestId,

  /// Whether the page is "Comprar no estrangeiro".
  final bool importing = false,
  super.key,
}) extends StatefulWidget {
  /// The oldest year the form takes (as request_bike_value).
  static const firstYear = 1990;

  @override
  State<BikeValuePage> createState() => _BikeValuePageState();
}

/// What "Calcular" gave: the value, or null while the request waits for a
/// collection.
typedef _Outcome = ({
  String name,
  int year,
  int? mileage,
  BikeValue? value,
  MarketBehaviour? market,
});

/// The dropdown's entry that opens the make and model form.
const _otherModel = '';

class _BikeValuePageState extends State<BikeValuePage> {
  final _repository = getIt<MarketBehaviourRepository>();
  final _signedIn = getIt<SessionCubit>().state.signedIn;
  late Future<List<ModelMarket>> _models = _loadModels();
  List<BikeValueRequest> _requests = const [];
  final _form = GlobalKey<FormState>();
  final _year = TextEditingController();
  final _mileage = TextEditingController();
  String? _motorcycleId;

  /// What the owner says of the bike; it adjusts the value shown, at once,
  /// and is not part of the request.
  BikeCondition _condition = const BikeCondition();

  /// Bumped to reset the dropdown when the make and model form is closed
  /// without a model.
  int _resets = 0;

  /// Models added through "Outra marca ou modelo…" on this visit.
  final _added = <String, String>{};

  /// What was asked and its value, once "Calcular" was pressed.
  Future<_Outcome>? _outcome;
  String? _shownRequest;

  Future<List<ModelMarket>> _loadModels() async {
    final models = await _repository.getTrackedModels();
    return [...models]..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadRequests());
  }

  /// The account's requests; a failed read leaves the list as it was (it
  /// is only a shortcut to earlier answers).
  Future<void> _loadRequests() async {
    if (!_signedIn) return;
    try {
      final requests = await _repository.getBikeValueRequests();
      if (!mounted) return;
      setState(() => _requests = requests);
      _openRequest(requests);
    } catch (_) {
      // Kept as it was.
    }
  }

  @override
  void didUpdateWidget(BikeValuePage old) {
    super.didUpdateWidget(old);
    if (widget.requestId != old.requestId) unawaited(_loadRequests());
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

  /// The models to choose from: the collected ones, those of the account's
  /// requests and those added now, by id.
  Map<String, String> _choices(
    List<ModelMarket> models,
    List<BikeValueRequest> requests,
  ) {
    final choices = {
      for (final m in models) m.motorcycleId: m.name,
      for (final r in requests) r.motorcycleId: r.name,
      ..._added,
    };
    final sorted = choices.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return Map.fromEntries(sorted);
  }

  /// Opens the request the notification named, once.
  void _openRequest(List<BikeValueRequest> requests) {
    final id = widget.requestId;
    if (id == null || id == _shownRequest) return;
    for (final request in requests) {
      if (request.id == id) {
        _shownRequest = id;
        _show(request);
      }
    }
  }

  /// Fills the form with [request] and shows its value or that it waits.
  void _show(BikeValueRequest request) {
    _year.text = '${request.year}';
    _mileage.text = request.mileage?.toString() ?? '';
    setState(() {
      _added.putIfAbsent(request.motorcycleId, () => request.name);
      _motorcycleId = request.motorcycleId;
      _outcome = _valueOf(
        request.motorcycleId,
        request.name,
        year: request.year,
        mileage: request.mileage,
        waiting: request.waiting,
      );
    });
  }

  Future<_Outcome> _valueOf(
    String motorcycleId,
    String name, {
    required int year,
    required int? mileage,
    bool waiting = false,
  }) async {
    if (waiting) {
      return (
        name: name,
        year: year,
        mileage: mileage,
        value: null,
        market: null,
      );
    }
    final (value, market) = await (
      _repository.getBikeValue(motorcycleId, year: year, mileage: mileage),
      _repository.getForModel(motorcycleId),
    ).wait;
    return (
      name: name,
      year: year,
      mileage: mileage,
      value: value,
      market: market,
    );
  }

  Future<_Outcome> _ask(
    String motorcycleId,
    String name, {
    required int year,
    required int? mileage,
  }) async {
    if (!_signedIn) {
      return await _valueOf(motorcycleId, name, year: year, mileage: mileage);
    }
    final asked = await _repository.requestBikeValue(
      motorcycleId,
      year: year,
      mileage: mileage,
    );
    await _loadRequests();
    return await _valueOf(
      motorcycleId,
      name,
      year: year,
      mileage: mileage,
      waiting: !asked.ready,
    );
  }

  void _calculate(Map<String, String> choices) {
    if (!_form.currentState!.validate()) return;
    final id = _motorcycleId!;
    setState(() {
      _added.putIfAbsent(id, () => choices[id]!);
      _outcome = _ask(
        id,
        choices[id]!,
        year: int.parse(_year.text.trim()),
        mileage: _mileage.text.trim().isEmpty ? null : _mileageValue(),
      );
    });
  }

  /// "Outra marca ou modelo…": the make and model form, then the catalog
  /// model for it (added when new, not followed).
  Future<void> _pickOther() async {
    final picked = await showAddModelSheet(
      context,
      getIt<CatalogRepository>(),
      forValue: true,
    );
    if (!mounted) return;
    if (picked == null) {
      setState(() => _resets++);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.strings.bikeValueCouldNotUseModel;
    try {
      final id = await _repository.bikeValueModel(
        brand: picked.brand,
        model: picked.model,
        olxSearch: picked.olxSearch,
        standvirtualSearch: picked.standvirtualSearch,
        engineCcMin: picked.engineCcMin,
        engineCcMax: picked.engineCcMax,
      );
      if (!mounted) return;
      setState(() {
        _added[id] = '${picked.brand} ${picked.model}';
        _motorcycleId = id;
      });
    } catch (_) {
      if (mounted) setState(() => _resets++);
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: Text(
          widget.importing
              ? context.strings.importPageTitle
              : context.strings.bikeValueTitle,
        ),
      ),
      body: TrackedModelsBuilder(
        future: _models,
        allowEmpty: _signedIn,
        onRetry: () => setState(() => _models = _loadModels()),
        builder: (context, models) {
          final choices = _choices(models, _requests);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(switch ((widget.importing, _signedIn)) {
                (true, _) => context.strings.importPageIntro,
                (false, true) => context.strings.bikeValueIntroAnyModel,
                (false, false) => context.strings.bikeValueIntro,
              }),
              const SizedBox(height: 16),
              _formFields(context, choices),
              const SizedBox(height: 16),
              if (_outcome != null) _result(context, choices),
              if (_requests.isNotEmpty) ..._requestList(context, _requests),
            ],
          );
        },
      ),
    );
  }

  Widget _formFields(BuildContext context, Map<String, String> choices) {
    final strings = context.strings;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            // Rebuilt when a model is picked from outside the dropdown.
            key: ValueKey((_motorcycleId, _resets)),
            initialValue: _motorcycleId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: strings.model,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final MapEntry(:key, :value) in choices.entries)
                DropdownMenuItem(value: key, child: Text(value)),
              if (_signedIn)
                DropdownMenuItem(
                  value: _otherModel,
                  child: Text(strings.bikeValueOtherModel),
                ),
            ],
            validator: (value) => value == null || value == _otherModel
                ? strings.bikeValueChooseModel
                : null,
            onChanged: (value) {
              if (value == _otherModel) {
                unawaited(_pickOther());
              } else {
                setState(() => _motorcycleId = value);
              }
            },
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
          const SizedBox(height: 20),
          ..._conditionFields(context),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _calculate(choices),
            icon: const Icon(Icons.calculate_outlined),
            label: Text(strings.bikeValueCalculate),
          ),
        ],
      ),
    );
  }

  List<Widget> _conditionFields(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    void update(BikeCondition condition) =>
        setState(() => _condition = condition);
    return [
      Text(strings.bikeValueCondition, style: theme.textTheme.titleSmall),
      const SizedBox(height: 4),
      Text(
        strings.bikeValueConditionHint,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 12),
      _ConditionChoice(
        label: strings.bikeValueDamage,
        value: _condition.damage,
        options: {
          BikeDamage.none: strings.bikeValueDamageNone,
          BikeDamage.dropped: strings.bikeValueDamageDropped,
          BikeDamage.accident: strings.bikeValueDamageAccident,
        },
        onChanged: (damage) => update(_condition.copyWith(damage: damage)),
      ),
      const SizedBox(height: 12),
      _ConditionChoice(
        label: strings.bikeValueOwners,
        value: _condition.owners,
        options: {
          BikeOwners.unknown: strings.bikeValueUnknown,
          BikeOwners.one: strings.bikeValueOwnersOne,
          BikeOwners.two: strings.bikeValueOwnersTwo,
          BikeOwners.threeOrMore: strings.bikeValueOwnersMore,
        },
        onChanged: (owners) => update(_condition.copyWith(owners: owners)),
      ),
      const SizedBox(height: 12),
      _ConditionChoice(
        label: strings.bikeValueServiceBook,
        value: _condition.serviceBook,
        options: {
          BikeServiceBook.unknown: strings.bikeValueUnknown,
          BikeServiceBook.yes: strings.bikeValueServiceBookYes,
          BikeServiceBook.no: strings.bikeValueServiceBookNo,
        },
        onChanged: (book) => update(_condition.copyWith(serviceBook: book)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(strings.bikeValueWarranty),
        value: _condition.warranty,
        onChanged: (warranty) =>
            update(_condition.copyWith(warranty: warranty)),
      ),
    ];
  }

  Widget _result(BuildContext context, Map<String, String> choices) {
    return FutureBuilder<_Outcome>(
      future: _outcome,
      builder: (context, snapshot) {
        final strings = context.strings;
        if (snapshot.error is BikeValueRequestLimit) {
          return StateMessage(
            icon: Icons.hourglass_top,
            title: strings.bikeValueRequestLimit,
          );
        }
        if (snapshot.hasError) {
          return StateMessage(
            icon: Icons.cloud_off_outlined,
            title: strings.bikeValueCouldNotCalculate,
            actionLabel: strings.retry,
            onAction: () => _calculate(choices),
          );
        }
        final outcome = snapshot.data;
        if (outcome == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final theme = Theme.of(context);
        final muted = theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
        final value = outcome.value;
        final card = Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${outcome.name} ${outcome.year}',
                  style: theme.textTheme.titleMedium,
                ),
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
                    outcome.market,
                    condition: _condition,
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
        if (value == null || !widget.importing) return card;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ImportCostCard(
              estimate: conditionEstimate(value, _condition),
              year: outcome.year,
              mileage: outcome.mileage,
            ),
            const SizedBox(height: 16),
            card,
          ],
        );
      },
    );
  }

  List<Widget> _requestList(
    BuildContext context,
    List<BikeValueRequest> requests,
  ) {
    final theme = Theme.of(context);
    return [
      const SizedBox(height: 24),
      Text(
        context.strings.bikeValueRequests,
        style: theme.textTheme.titleSmall,
      ),
      for (final request in requests)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            request.waiting ? Icons.hourglass_top : Icons.euro,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          title: Text(request.name),
          subtitle: Text(
            bikeValueRequestLine(request, language: context.language),
          ),
          onTap: () => _show(request),
        ),
    ];
  }
}

/// One of the condition's answers, as a dropdown.
class const _ConditionChoice<T>({
  required final String label,
  required final T value,
  required final Map<T, String> options,
  required final ValueChanged<T> onChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final MapEntry(:key, value: text) in options.entries)
        DropdownMenuItem(value: key, child: Text(text)),
    ],
    onChanged: (picked) {
      if (picked != null) onChanged(picked);
    },
  );
}

const _icons = {
  BikeValueLineKind.estimate: Icons.euro,
  BikeValueLineKind.condition: Icons.tune,
  BikeValueLineKind.asking: Icons.sell_outlined,
  BikeValueLineKind.time: Icons.schedule,
  BikeValueLineKind.tradeIn: Icons.store_outlined,
};
