import 'package:flutter/material.dart';

import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_filters.dart';
import '../../domain/entities/motorcycle_option.dart';
import '../filter_fields_text.dart';
import '../saved_search_summary.dart';
import '../score_criteria.dart';
import '../score_explanation.dart';

class FiltersSheet extends StatefulWidget {
  const FiltersSheet({
    required this.initial,
    required this.motorcycles,
    super.key,
  });

  final ListingFilters initial;
  final List<MotorcycleOption> motorcycles;

  @override
  State<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<FiltersSheet> {
  late final Set<String> _motorcycleIds = {...widget.initial.motorcycleIds};
  late SellerType? _sellerType = widget.initial.sellerType;
  late bool _activeOnly = widget.initial.activeOnly;
  late int? _minDealScore = widget.initial.minDealScore;
  late int? _maxRiskScore = widget.initial.maxRiskScore;
  late int? _maxDistanceKm = widget.initial.maxDistanceKm;
  late final Set<String> _extras = {...widget.initial.extras};
  late bool _onlyMyColours = widget.initial.onlyMyColours;

  late final _year = TextEditingController(
    text: widget.initial.minYear?.toString() ?? '',
  );
  late final _price = TextEditingController(
    text: widget.initial.maxPrice?.toStringAsFixed(0) ?? '',
  );
  late final _mileage = TextEditingController(
    text: widget.initial.maxMileage?.toString() ?? '',
  );
  late final _location = TextEditingController(
    text: widget.initial.location ?? '',
  );

  @override
  void dispose() {
    _year.dispose();
    _price.dispose();
    _mileage.dispose();
    _location.dispose();
    super.dispose();
  }

  ListingFilters _build() {
    return ListingFilters(
      // In the catalog's order, so equal choices compare equal; a model no
      // longer in the list stays asked for.
      motorcycleIds: [
        for (final m in widget.motorcycles)
          if (_motorcycleIds.contains(m.id)) m.id,
        ..._motorcycleIds.where(
          (id) => !widget.motorcycles.any((m) => m.id == id),
        ),
      ],
      minYear: parseWholeNumberField(_year.text),
      maxPrice: parsePriceField(_price.text),
      maxMileage: parseWholeNumberField(_mileage.text),
      location: parseTextField(_location.text),
      sellerType: _sellerType,
      minDealScore: _minDealScore,
      maxRiskScore: _maxRiskScore,
      maxDistanceKm: _maxDistanceKm,
      // In the order of the options, so equal choices compare equal.
      extras: [
        for (final code in extraLabels.keys)
          if (_extras.contains(code)) code,
      ],
      onlyMyColours: _onlyMyColours,
      activeOnly: _activeOnly,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Filtros',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              // The sheet fills the screen on a phone, so there is no
              // backdrop to tap: closing keeps the current filters.
              IconButton(
                tooltip: 'Fechar',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Modelos', style: Theme.of(context).textTheme.titleSmall),
          Text(
            'Escolha um ou mais; sem nenhum, todos os seus modelos.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final MapEntry(key: brand, value: models)
              in modelsByBrand(widget.motorcycles).entries) ...[
            const SizedBox(height: 8),
            Text(brand, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in models)
                  FilterChip(
                    label: Text(m.model),
                    selected: _motorcycleIds.contains(m.id),
                    onSelected: (selected) => setState(
                      () => selected
                          ? _motorcycleIds.add(m.id)
                          : _motorcycleIds.remove(m.id),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _NumberField(controller: _year, label: 'Ano mínimo'),
          const SizedBox(height: 12),
          _NumberField(controller: _price, label: 'Preço máximo (€)'),
          const SizedBox(height: 12),
          _NumberField(
            controller: _mileage,
            label: 'Quilometragem máxima (km)',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            decoration: const InputDecoration(
              labelText: 'Localização',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _maxDistanceKm,
            decoration: const InputDecoration(
              labelText: 'Distância máxima',
              helperText: 'A partir da sua localidade (em Mais)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Qualquer')),
              // Keeps a saved value that is not one of the options.
              for (final km in {...maxDistanceOptions, ?_maxDistanceKm})
                DropdownMenuItem(value: km, child: Text(maxDistanceLabel(km))),
            ],
            onChanged: (value) => setState(() => _maxDistanceKm = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _minDealScore,
            decoration: const InputDecoration(
              labelText: 'Deal Score mínimo',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Qualquer')),
              for (final min in minDealScoreOptions)
                DropdownMenuItem(
                  value: min,
                  child: Text(dealScoreOptionLabel(min)),
                ),
            ],
            onChanged: (value) => setState(() => _minDealScore = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _maxRiskScore,
            decoration: const InputDecoration(
              labelText: 'Risco máximo',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Qualquer')),
              for (final max in maxRiskScoreOptions)
                DropdownMenuItem(
                  value: max,
                  child: Text(riskCriterionLabel(max)),
                ),
            ],
            onChanged: (value) => setState(() => _maxRiskScore = value),
          ),
          const SizedBox(height: 16),
          Text('Equipamento', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final MapEntry(key: code, value: label)
                  in extraLabels.entries)
                FilterChip(
                  label: Text(label),
                  selected: _extras.contains(code),
                  onSelected: (selected) => setState(
                    () => selected ? _extras.add(code) : _extras.remove(code),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<SellerType?>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: null, label: Text('Todos')),
              ButtonSegment(
                value: SellerType.private,
                label: Text('Particular'),
              ),
              ButtonSegment(
                value: SellerType.dealer,
                label: Text('Profissional'),
              ),
            ],
            selected: {_sellerType},
            onSelectionChanged: (selection) =>
                setState(() => _sellerType = selection.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Só nas suas cores'),
            subtitle: const Text(
              'As cores preferidas de cada modelo, em Modelos acompanhados',
            ),
            value: _onlyMyColours,
            onChanged: (value) => setState(() => _onlyMyColours = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Apenas anúncios ativos'),
            value: _activeOnly,
            onChanged: (value) => setState(() => _activeOnly = value),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(ListingFilters.empty),
                  child: const Text('Limpar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_build()),
                  child: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
