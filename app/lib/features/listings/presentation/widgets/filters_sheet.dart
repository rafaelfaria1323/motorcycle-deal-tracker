import 'package:flutter/material.dart';

import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_filters.dart';
import '../../domain/entities/motorcycle_option.dart';
import '../score_criteria.dart';

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
  late String? _motorcycleId = widget.initial.motorcycleId;
  late SellerType? _sellerType = widget.initial.sellerType;
  late bool _activeOnly = widget.initial.activeOnly;
  late int? _minDealScore = widget.initial.minDealScore;
  late int? _maxRiskScore = widget.initial.maxRiskScore;

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
    final location = _location.text.trim();
    return ListingFilters(
      motorcycleId: _motorcycleId,
      minYear: int.tryParse(_year.text.trim()),
      maxPrice: double.tryParse(_price.text.trim().replaceAll(',', '.')),
      maxMileage: int.tryParse(_mileage.text.trim()),
      location: location.isEmpty ? null : location,
      sellerType: _sellerType,
      minDealScore: _minDealScore,
      maxRiskScore: _maxRiskScore,
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
          Text('Filtros', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _motorcycleId,
            decoration: const InputDecoration(
              labelText: 'Modelo',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos')),
              for (final m in widget.motorcycles)
                DropdownMenuItem(
                  value: m.id,
                  child: Text('${m.brand} ${m.model}'),
                ),
            ],
            onChanged: (value) => setState(() => _motorcycleId = value),
          ),
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
