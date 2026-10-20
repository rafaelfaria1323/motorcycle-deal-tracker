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

/// Asks for a new model and its searches; returns null if cancelled. The
/// brand and model are picked from the sites' own lists (filled by the
/// collector), which also give the searches; typing everything by hand
/// stays possible.
Future<NewModel?> showAddModelSheet(
  BuildContext context,
  CatalogRepository repository,
) {
  return showModalBottomSheet<NewModel>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
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
  final _olx = TextEditingController();
  final _standvirtual = TextEditingController();
  final _aliases = TextEditingController();
  Map<String, String> _problems = const {};

  /// The sites' brands; null while loading, empty when unknown (the
  /// collector has not run yet, or loading failed): then only typing works.
  List<SiteMake>? _makes;
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
    for (final c in [
      _brand,
      _model,
      _cc,
      _year,
      _olx,
      _standvirtual,
      _aliases,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMakes() async {
    List<SiteMake> makes;
    try {
      makes = sortedMakes(await widget.repository.getSiteMakes());
    } catch (_) {
      makes = const [];
    }
    if (mounted) setState(() => _makes = makes);
  }

  Future<void> _pickMake(SiteMake? make) async {
    setState(() {
      _make = make;
      _picked = null;
      _makeModels = const [];
      _loadingModels = make != null;
    });
    if (make == null) return;
    List<SiteModel> models;
    try {
      models = await widget.repository.getSiteModels(make.id);
    } catch (_) {
      models = const [];
    }
    if (mounted && _make == make) {
      setState(() {
        _makeModels = models;
        _loadingModels = false;
      });
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
      if (picked != null) {
        _brand.text = picked.brand;
        _model.text = picked.model;
        _standvirtual.text = picked.standvirtual;
        _olx.text = picked.olx ?? '';
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
        olxSearch: _usePicker ? (picked?.olx ?? '') : _olx.text,
        standvirtualSearch: _usePicker
            ? (picked?.standvirtual ?? '')
            : _standvirtual.text,
      ),
      'cc': ?engine.error,
    };
    if (_usePicker) {
      // The picker always gives a Standvirtual search once a model is
      // chosen; a missing one only means no model was chosen.
      problems.remove('olx');
      if (_make == null) problems['brand'] = 'Escolha a marca';
      if (picked == null) problems['model'] = 'Escolha o modelo';
    }
    if (problems.isNotEmpty) {
      setState(() => _problems = problems);
      return;
    }
    String? optional(String text) => text.trim().isEmpty ? null : text.trim();
    final range = engine.cc == null ? null : engineRange(engine.cc!);
    Navigator.of(context).pop((
      brand: picked?.brand ?? _brand.text.trim(),
      model: picked?.model ?? _model.text.trim(),
      minYear: int.parse(_year.text.trim()),
      olxSearch: picked == null ? optional(_olx.text) : picked.olx,
      standvirtualSearch: picked == null
          ? optional(_standvirtual.text)
          : picked.standvirtual,
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

  List<Widget> _pickerFields(BuildContext context) {
    final makes = _makes!;
    final models = pickerModels(_makeModels);
    final picked = _fromPicker;
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
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
            for (final m in models)
              DropdownMenuEntry(value: m, label: adsLabel(m.name, m.ads)),
          ],
        ),
      ),
      _field(
        _cc,
        'Cilindrada (opcional)',
        problemKey: 'cc',
        keyboard: TextInputType.number,
        helper:
            'Vazio: todas as cilindradas do modelo. Ex.: 350 para '
            'acompanhar só a Forza 350.',
      ),
      if (picked != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            [
              'Fica: ${picked.brand} ${picked.model}',
              'Standvirtual: ${picked.standvirtual}',
              picked.olx == null
                  ? 'OLX: este modelo não está na lista conhecida do OLX, '
                        'por isso só o Standvirtual é pesquisado. Para '
                        'juntar o OLX, use "Escrever à mão".'
                  : 'OLX: ${picked.olx}',
            ].join('\n'),
            style: muted,
          ),
        ),
    ];
  }

  List<Widget> _typedFields() => [
    _field(_brand, 'Marca', problemKey: 'brand'),
    _field(_model, 'Modelo', problemKey: 'model'),
    _field(
      _cc,
      'Cilindrada (opcional)',
      problemKey: 'cc',
      keyboard: TextInputType.number,
      helper:
          'Vazio: todas as cilindradas. Só as motas desta cilindrada '
          '(10 % para cima ou para baixo) contam como este modelo.',
    ),
    _field(
      _olx,
      'Pesquisa no OLX',
      problemKey: 'olx',
      keyboard: TextInputType.url,
    ),
    _field(
      _standvirtual,
      'Pesquisa no Standvirtual (opcional)',
      problemKey: 'standvirtual',
      keyboard: TextInputType.url,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final loading = _makes == null;
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
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Text(
                _usePicker
                    ? 'Escolha a marca e o modelo (com o número de anúncios '
                          'no Standvirtual). As pesquisas são criadas '
                          'automaticamente.'
                    : 'Para a pesquisa: abra o OLX (ou o Standvirtual) no '
                          'browser, escolha Motociclos, a marca e o modelo, e '
                          'copie o endereço. O ano é acrescentado '
                          'automaticamente.',
              ),
              const SizedBox(height: 16),
              ...(_usePicker ? _pickerFields(context) : _typedFields()),
              _field(
                _year,
                'Desde o ano',
                problemKey: 'year',
                keyboard: TextInputType.number,
              ),
              _field(
                _aliases,
                'Outros nomes (opcional)',
                helper:
                    'Como os vendedores também escrevem o modelo, separados '
                    'por vírgulas. Ex.: Z 650, Z-650',
              ),
              const SizedBox(height: 4),
              FilledButton(onPressed: _submit, child: const Text('Adicionar')),
              if (_usePicker)
                TextButton(
                  onPressed: _typeByHand,
                  child: const Text('Escrever à mão'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
