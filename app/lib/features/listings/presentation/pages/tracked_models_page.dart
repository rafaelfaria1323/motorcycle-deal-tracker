import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/collapsible_section.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/entities/catalog_model.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../colour_text.dart';
import '../cubit/favourites_cubit.dart';
import '../cubit/listings_cubit.dart';
import '../filter_sections_text.dart';
import '../tracked_models_text.dart';
import '../widgets/add_model_sheet.dart';
import '../../../../core/localization/localizations.dart';

/// Lets the account choose which catalog models it follows, from which
/// year, and add new ones. The collector runs the searches of the models
/// any account follows.
class const TrackedModelsPage({super.key}) extends StatefulWidget {
  @override
  State<TrackedModelsPage> createState() => _TrackedModelsPageState();
}

class _TrackedModelsPageState extends State<TrackedModelsPage> {
  final _repository = getIt<CatalogRepository>();
  List<CatalogModel>? _models;
  bool _failed = false;

  /// Models with a change on its way, so a switch can't be flipped twice.
  final _saving = <String>{};

  /// Something was saved: Ofertas' models and listings change with it.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_changed) {
      unawaited(getIt<ListingsCubit>().load(models: true));
      // The favourite-colour marks come with the listings.
      unawaited(getIt<FavouritesCubit>().load());
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final models = await _repository.getModels();
      if (mounted) setState(() => _models = models);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Shows [change] at once, saves it, and puts [model] back if that fails.
  Future<void> _save(
    CatalogModel model,
    CatalogModel change,
    Future<void> Function() save,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving.add(model.id);
      _replace(change);
    });
    try {
      await save();
      _changed = true;
      // Other accounts' models count in the searches: show what is stored.
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _replace(model));
      showMessage(messenger, _errorText(e));
      // Part of a change may have been saved: show what is stored.
      await _load();
    } finally {
      if (mounted) setState(() => _saving.remove(model.id));
    }
  }

  Future<void> _toggle(CatalogModel model, bool tracked) => _save(
    model,
    model.copyWith(isTracked: tracked),
    () => _repository.setTracked(model.id, tracked: tracked),
  );

  Future<void> _edit(CatalogModel model) async {
    final edited = await showDialog<_ModelEdit>(
      context: context,
      builder: (_) => _ModelDialog(model: model),
    );
    if (edited == null) return;
    final yearChanged = edited.year != model.minYear;
    final priceChanged = edited.price != model.newPrice;
    final coloursChanged = !_sameColours(edited.colours, model.colours);
    if (!yearChanged && !priceChanged && !coloursChanged) return;

    await _save(
      model,
      model
          .copyWith(minYear: edited.year, colours: edited.colours)
          .withNewPrice(
            edited.price,
            priceChanged
                ? DateTime.now()
                : (model.newPriceCheckedAt ?? DateTime.now()),
          ),
      () async {
        if (yearChanged) await _repository.setMinYear(model.id, edited.year);
        if (priceChanged) {
          await _repository.setNewPrice(model.id, edited.price);
        }
        if (coloursChanged) {
          await _repository.setColours(model.id, edited.colours);
        }
      },
    );
  }

  static bool _sameColours(List<String> a, List<String> b) =>
      a.toSet().containsAll(b) && b.toSet().containsAll(a);

  Future<void> _add() async {
    final messageStrings = context.strings;

    final messenger = ScaffoldMessenger.of(context);
    final added = await showAddModelSheet(context, _repository);
    if (added == null) return;
    try {
      await _repository.addModel(
        brand: added.brand,
        model: added.model,
        minYear: added.minYear,
        olxSearch: added.olxSearch,
        standvirtualSearch: added.standvirtualSearch,
        aliases: added.aliases,
        engineCcMin: added.engineCcMin,
        engineCcMax: added.engineCcMax,
      );
      _changed = true;
      showMessage(
        messenger,
        messageStrings.addedIncludedInNextCollection(
          brand: added.brand,
          model: added.model,
        ),
      );
      await _load();
    } catch (e) {
      showMessage(messenger, _errorText(e));
    }
  }

  String _errorText(Object e) => catalogSaveErrorText(
    e is PostgrestException ? e.code : null,
    language: context.language,
  );

  void _replace(CatalogModel model) {
    _models = [for (final m in _models!) m.id == model.id ? model : m];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: Text(context.strings.followedModels),
      ),
      floatingActionButton: _models == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(context.strings.addModel),
            ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_failed) {
      return StateMessage(
        icon: Icons.cloud_off_outlined,
        title: context.strings.couldNotLoadModels,
        actionLabel: context.strings.retry,
        onAction: _load,
      );
    }
    final models = _models;
    if (models == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            context.strings.chooseModelsYouWantToFollowAndEarliest,
            style: muted,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            searchesLine(models, language: context.language),
            style: muted,
          ),
        ),
        for (final MapEntry(key: brand, value: brandModels) in modelsByBrand(
          models,
        ).entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(brand, style: theme.textTheme.titleMedium),
          ),
          for (final m in brandModels)
            ListTile(
              title: Text(m.model),
              subtitle: Text(
                '${modelSubtitle(m, language: context.language)}\n${newPriceSubtitle(m, language: context.language)}',
              ),
              isThreeLine: true,
              onTap: _saving.contains(m.id) ? null : () => _edit(m),
              trailing: Switch(
                value: m.isTracked,
                onChanged: _saving.contains(m.id)
                    ? null
                    : (tracked) => _toggle(m, tracked),
              ),
            ),
        ],
      ],
    );
  }
}

typedef _ModelEdit = ({int year, double? price, List<String> colours});

/// Edits a model's first year, favourite colours and new-bike price;
/// returns null if cancelled.
class const _ModelDialog({required final CatalogModel model})
    extends StatefulWidget {
  @override
  State<_ModelDialog> createState() => _ModelDialogState();
}

class _ModelDialogState extends State<_ModelDialog> {
  late int _year = widget.model.minYear;
  late final Set<String> _colours = {...widget.model.colours};
  late final _price = TextEditingController(
    text: widget.model.newPrice?.toStringAsFixed(0) ?? '',
  );
  final _maxYear = DateTime.now().year + 1;
  String? _priceError;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = parseNewPrice(_price.text, language: context.language);
    if (parsed.error != null) {
      setState(() => _priceError = parsed.error);
      return;
    }
    Navigator.of(context).pop((
      year: _year,
      price: parsed.price,
      // In the offered order, so equal choices compare equal.
      colours: [
        for (final code in colourLabels(language: context.language).keys)
          if (_colours.contains(code)) code,
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('${widget.model.brand} ${widget.model.model}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.strings.fromYear, style: theme.textTheme.titleSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _year > 1990
                      ? () => setState(() => _year--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('$_year', style: theme.textTheme.headlineSmall),
                IconButton(
                  onPressed: _year < _maxYear
                      ? () => setState(() => _year++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            Text(context.strings.firstYearHelp),
            const SizedBox(height: 16),
            CollapsibleSection(
              title: context.strings.preferredColours,
              summary: chosenSummary(
                [
                  for (final MapEntry(key: code, value: label) in colourLabels(
                    language: context.language,
                  ).entries)
                    if (_colours.contains(code)) label,
                ],
                none: context.strings.any,
                language: context.language,
              ),
              active: _colours.isNotEmpty,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final MapEntry(key: code, value: label)
                        in colourLabels(language: context.language).entries)
                      FilterChip(
                        label: Text(label),
                        selected: _colours.contains(code),
                        onSelected: (selected) => setState(
                          () => selected
                              ? _colours.add(code)
                              : _colours.remove(code),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(context.strings.listingsInTheseColoursAreMarkedAndYou),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: context.strings.newBikePriceInput,
                helperText: context.strings.newPriceHelp,
                helperMaxLines: 3,
                errorText: _priceError,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.strings.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(context.strings.save)),
      ],
    );
  }
}
