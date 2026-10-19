import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/entities/catalog_model.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../tracked_models_text.dart';
import '../widgets/add_model_sheet.dart';

/// Lets the owner choose which catalog models are tracked, from which year,
/// and add new ones. The collector runs the searches of the tracked models.
class TrackedModelsPage extends StatefulWidget {
  const TrackedModelsPage({super.key});

  @override
  State<TrackedModelsPage> createState() => _TrackedModelsPageState();
}

class _TrackedModelsPageState extends State<TrackedModelsPage> {
  final _repository = getIt<CatalogRepository>();
  List<CatalogModel>? _models;
  bool _failed = false;

  /// Models with a change on its way, so a switch can't be flipped twice.
  final _saving = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _replace(model));
      messenger.showSnackBar(SnackBar(content: Text(_errorText(e))));
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
    final edited = await showDialog<({int year, double? price})>(
      context: context,
      builder: (_) => _ModelDialog(model: model),
    );
    if (edited == null) return;
    final yearChanged = edited.year != model.minYear;
    final priceChanged = edited.price != model.newPrice;
    if (!yearChanged && !priceChanged) return;

    await _save(
      model,
      model
          .copyWith(minYear: edited.year)
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
      },
    );
  }

  Future<void> _add() async {
    final messenger = ScaffoldMessenger.of(context);
    final added = await showAddModelSheet(context);
    if (added == null) return;
    try {
      await _repository.addModel(
        brand: added.brand,
        model: added.model,
        minYear: added.minYear,
        olxSearch: added.olxSearch,
        standvirtualSearch: added.standvirtualSearch,
        aliases: added.aliases,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${added.brand} ${added.model} adicionado: entra na próxima '
            'recolha',
          ),
        ),
      );
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_errorText(e))));
    }
  }

  String _errorText(Object e) =>
      catalogSaveErrorText(e is PostgrestException ? e.code : null);

  void _replace(CatalogModel model) {
    _models = [for (final m in _models!) m.id == model.id ? model : m];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modelos acompanhados')),
      floatingActionButton: _models == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar modelo'),
            ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_failed) {
      return StateMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível carregar os modelos',
        actionLabel: 'Tentar novamente',
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
    final budget = budgetLines(models);

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            'O recolhedor pesquisa só os modelos ligados e dá-lhes pontuação, '
            'alertas e dados de mercado. As alterações contam a partir da '
            'próxima recolha (até 4 horas). Toque num modelo para mudar o ano '
            'ou o preço de uma nova.',
            style: muted,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(budget.first, style: muted),
        ),
        if (budget.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(budget[1])),
              ],
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
              subtitle: Text('${modelSubtitle(m)}\n${newPriceSubtitle(m)}'),
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

/// Edits a model's first year and new-bike price; returns null if
/// cancelled.
class _ModelDialog extends StatefulWidget {
  const _ModelDialog({required this.model});

  final CatalogModel model;

  @override
  State<_ModelDialog> createState() => _ModelDialogState();
}

class _ModelDialogState extends State<_ModelDialog> {
  late int _year = widget.model.minYear;
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
    final parsed = parseNewPrice(_price.text);
    if (parsed.error != null) {
      setState(() => _priceError = parsed.error);
      return;
    }
    Navigator.of(context).pop((year: _year, price: parsed.price));
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
            Text('Desde o ano', style: theme.textTheme.titleSmall),
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
            const Text(
              'Anúncios mais antigos são ignorados. Um ano mais antigo traz '
              'mais anúncios, mas a pesquisa ocupa mais pedidos.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Preço de uma nova (€)',
                helperText:
                    'Preço de tabela no site da marca. Fica com a data de '
                    'hoje; vazio para apagar.',
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
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
