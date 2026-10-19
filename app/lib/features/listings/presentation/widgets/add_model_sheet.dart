import 'package:flutter/material.dart';

import '../tracked_models_text.dart';

/// What the "add a model" form returns.
typedef NewModel = ({
  String brand,
  String model,
  int minYear,
  String? olxSearch,
  String? standvirtualSearch,
  List<String> aliases,
});

/// Asks for a new model and its searches; returns null if cancelled.
Future<NewModel?> showAddModelSheet(BuildContext context) {
  return showModalBottomSheet<NewModel>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _AddModelSheet(),
  );
}

class _AddModelSheet extends StatefulWidget {
  const _AddModelSheet();

  @override
  State<_AddModelSheet> createState() => _AddModelSheetState();
}

class _AddModelSheetState extends State<_AddModelSheet> {
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController(text: '${DateTime.now().year - 3}');
  final _olx = TextEditingController();
  final _standvirtual = TextEditingController();
  final _aliases = TextEditingController();
  Map<String, String> _problems = const {};

  @override
  void dispose() {
    for (final c in [_brand, _model, _year, _olx, _standvirtual, _aliases]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final problems = newModelProblems(
      brand: _brand.text,
      model: _model.text,
      year: _year.text,
      olxSearch: _olx.text,
      standvirtualSearch: _standvirtual.text,
    );
    if (problems.isNotEmpty) {
      setState(() => _problems = problems);
      return;
    }
    String? optional(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    Navigator.of(context).pop((
      brand: _brand.text.trim(),
      model: _model.text.trim(),
      minYear: int.parse(_year.text.trim()),
      olxSearch: optional(_olx),
      standvirtualSearch: optional(_standvirtual),
      aliases: parseAliases(_aliases.text),
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

  @override
  Widget build(BuildContext context) {
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
              'Para a pesquisa: abrir o OLX (ou o Standvirtual) no browser, '
              'escolher Motociclos, a marca e o modelo, e copiar o endereço. '
              'O ano é acrescentado automaticamente.',
            ),
            const SizedBox(height: 16),
            _field(_brand, 'Marca', problemKey: 'brand'),
            _field(_model, 'Modelo', problemKey: 'model'),
            _field(
              _year,
              'Desde o ano',
              problemKey: 'year',
              keyboard: TextInputType.number,
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
            _field(
              _aliases,
              'Outros nomes (opcional)',
              helper:
                  'Como os vendedores também escrevem o modelo, separados '
                  'por vírgulas. Ex.: Z 650, Z-650',
            ),
            const SizedBox(height: 4),
            FilledButton(onPressed: _submit, child: const Text('Adicionar')),
          ],
        ),
      ),
    );
  }
}
