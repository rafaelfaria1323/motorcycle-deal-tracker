import 'package:flutter/material.dart';

import '../../domain/entities/site_model.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../model_picker_text.dart';
import '../tracked_models_text.dart';

/// What the "add a model" form returns.
typedef NewModel = ({
  String brand,
  String model,
  int minYear,
  String? olxSearch,
  String? standvirtualSearch,
  List<String> aliases,
  int? engineCcMin,
  int? engineCcMax,
});

/// Asks for a model to track on both sites; returns null if cancelled.
/// Known site filters are kept; the database builds any missing searches.
Future<NewModel?> showAddModelSheet(
  BuildContext context,
  CatalogRepository repository,
) {
  return showModalBottomSheet<NewModel>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _AddModelSheet(repository),
  );
}

class _AddModelSheet extends StatefulWidget {
  const _AddModelSheet(this.repository);

  final CatalogRepository repository;

  @override
  State<_AddModelSheet> createState() => _AddModelSheetState();
}

class _AddModelSheetState extends State<_AddModelSheet> {
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _cc = TextEditingController();
  final _year = TextEditingController(text: '${DateTime.now().year - 3}');
  final _aliases = TextEditingController();
  Map<String, String> _problems = const {};

  List<SiteMake>? _makes;
  String? _makesProblem;
  String? _modelsProblem;
  bool _byHand = false;
  SiteMake? _make;
  List<SiteModel> _makeModels = const [];
  bool _loadingModels = false;
  SiteModel? _picked;

  @override
  void initState() {
    super.initState();
    _loadMakes();
    _cc.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_brand, _model, _cc, _year, _aliases]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMakes() async {
    try {
      final makes = sortedMakes(await widget.repository.getSiteMakes());
      if (mounted) setState(() => _makes = makes);
    } catch (_) {
      if (mounted) {
        setState(() {
          _makes = const [];
          _makesProblem =
              'Não foi possível carregar as marcas. '
              'Pode escrever a marca e o modelo.';
        });
      }
    }
  }

  Future<void> _pickMake(SiteMake? make) async {
    setState(() {
      _make = make;
      _picked = null;
      _makeModels = const [];
      _loadingModels = make != null;
      _modelsProblem = null;
    });
    if (make == null) return;
    try {
      final models = await widget.repository.getSiteModels(make.id);
      if (mounted && _make == make) {
        setState(() {
          _makeModels = models;
          _loadingModels = false;
        });
      }
    } catch (_) {
      if (mounted && _make == make) {
        setState(() {
          _modelsProblem =
              'Não foi possível carregar os modelos. '
              'Pode escrever o modelo à mão.';
          _loadingModels = false;
        });
      }
    }
  }

  /// The engine size typed, null when empty or invalid.
  int? get _engineCc => parseEngineCc(_cc.text).cc;

  /// What the picker gives: the name and the searches.
  ({String brand, String model, String standvirtual, String? olx})?
  get _fromPicker {
    final make = _make;
    final picked = _picked;
    if (make == null || picked == null) return null;
    final olx = olxModelFor(_makeModels, picked);
    return (
      brand: make.name,
      model: pickedModelName(picked.name, _engineCc),
      standvirtual: standvirtualSearchFor(make.id, picked.id, _engineCc),
      olx: olx == null ? null : olxSearchFor(olx.makeId, olx.id),
    );
  }

  bool get _usePicker => !_byHand && (_makes?.isNotEmpty ?? false);

  /// Switches to typing, starting from what was picked.
  void _typeByHand() {
    final picked = _fromPicker;
    setState(() {
      _byHand = true;
      _brand.text = _make?.name ?? _brand.text;
      if (picked != null) {
        _model.text = picked.model;
      }
    });
  }

  void _submit() {
    final picked = _usePicker ? _fromPicker : null;
    final engine = parseEngineCc(_cc.text);
    final problems = {
      ...newModelProblems(
        brand: _usePicker ? (_make?.name ?? '') : _brand.text,
        model: _usePicker ? (picked?.model ?? '') : _model.text,
        year: _year.text,
      ),
      'cc': ?engine.error,
    };
    if (_usePicker) {
      if (_make == null) problems['brand'] = 'Escolha a marca';
      if (picked == null) problems['model'] = 'Escolha o modelo';
    }
    if (problems.isNotEmpty) {
      setState(() => _problems = problems);
      return;
    }
    final range = engine.cc == null ? null : engineRange(engine.cc!);
    Navigator.of(context).pop((
      brand: picked?.brand ?? _brand.text.trim(),
      model: picked?.model ?? pickedModelName(_model.text, engine.cc),
      minYear: int.parse(_year.text.trim()),
      olxSearch: picked?.olx,
      standvirtualSearch: picked?.standvirtual,
      aliases: parseAliases(_aliases.text),
      engineCcMin: range?.min,
      engineCcMax: range?.max,
    ));
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? problemKey,
    String? helper,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 3,
          errorText: problemKey == null ? null : _problems[problemKey],
          errorMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  List<Widget> _pickerFields() {
    final makes = _makes!;
    final models = pickerModels(_makeModels);
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownMenu<SiteMake>(
          expandedInsets: EdgeInsets.zero,
          label: const Text('Marca'),
          menuHeight: 320,
          enableFilter: true,
          requestFocusOnTap: true,
          errorText: _problems['brand'],
          initialSelection: _make,
          onSelected: _pickMake,
          dropdownMenuEntries: [
            for (final m in makes) DropdownMenuEntry(value: m, label: m.name),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownMenu<SiteModel>(
          // A new brand starts with an empty model.
          key: ValueKey(_make?.id),
          expandedInsets: EdgeInsets.zero,
          label: Text(_loadingModels ? 'A carregar os modelos…' : 'Modelo'),
          enabled: _make != null && models.isNotEmpty,
          menuHeight: 320,
          enableFilter: true,
          requestFocusOnTap: true,
          errorText: _problems['model'],
          onSelected: (m) => setState(() => _picked = m),
          dropdownMenuEntries: [
            for (final m in models) DropdownMenuEntry(value: m, label: m.name),
          ],
        ),
      ),
    ];
  }

  List<Widget> _typedFields() => [
    _field(_brand, 'Marca', problemKey: 'brand'),
    _field(_model, 'Modelo', problemKey: 'model'),
  ];

  @override
  Widget build(BuildContext context) {
    final loading = _makes == null && !_byHand;
    final picked = _usePicker ? _fromPicker : null;
    final problem = _makesProblem ?? (_usePicker ? _modelsProblem : null);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Adicionar modelo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Escolha a marca e o modelo. Pesquisamos automaticamente '
              'no OLX e no Standvirtual.',
            ),
            const SizedBox(height: 16),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (problem != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    problem,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ...(_usePicker ? _pickerFields() : _typedFields()),
              _field(
                _cc,
                'Cilindrada (opcional)',
                problemKey: 'cc',
                keyboard: TextInputType.number,
                helper:
                    'Deixe em branco para todas as cilindradas. '
                    'Ex.: 350 para a Forza 350.',
              ),
              if (picked != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'A acompanhar: ${picked.brand} ${picked.model}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              _field(
                _year,
                'Desde o ano',
                problemKey: 'year',
                keyboard: TextInputType.number,
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8),
                shape: const Border(),
                collapsedShape: const Border(),
                title: const Text('Outros nomes do modelo'),
                children: [
                  _field(
                    _aliases,
                    'Outros nomes (opcional)',
                    helper:
                        'Como os vendedores também escrevem o modelo, '
                        'separados por vírgulas. Ex.: Z 650, Z-650',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _submit, child: const Text('Adicionar')),
            ],
            if (_usePicker || loading)
              TextButton(
                onPressed: _typeByHand,
                child: const Text('Escrever à mão'),
              ),
          ],
        ),
      ),
    );
  }
}
