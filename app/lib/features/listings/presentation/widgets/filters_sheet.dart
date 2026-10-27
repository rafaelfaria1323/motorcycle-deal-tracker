import 'package:flutter/material.dart';

import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_filters.dart';
import '../../domain/entities/motorcycle_option.dart';
import '../filter_fields_text.dart';
import '../saved_search_summary.dart';
import '../score_criteria.dart';
import '../score_explanation.dart';
import '../../../../core/localization/localizations.dart';

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
        for (final code in extraLabels(language: context.language).keys)
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
                  context.strings.filters,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              // The sheet fills the screen on a phone, so there is no
              // backdrop to tap: closing keeps the current filters.
              IconButton(
                tooltip: context.strings.close,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.strings.models,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            context.strings.chooseOneOrMoreLeaveEmptyForAll,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final MapEntry(key: brand, value: models) in modelsByBrand(
            widget.motorcycles,
          ).entries) ...[
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
          _NumberField(controller: _year, label: context.strings.earliestYear),
          const SizedBox(height: 12),
          _NumberField(
            controller: _price,
            label: context.strings.maximumPriceEUR,
          ),
          const SizedBox(height: 12),
          _NumberField(
            controller: _mileage,
            label: context.strings.maximumMileageKm,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            decoration: InputDecoration(
              labelText: context.strings.locationCompareText,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _maxDistanceKm,
            decoration: InputDecoration(
              labelText: context.strings.maximumDistance,
              helperText: context.strings.fromYourHomeLocationInMore,
              border: OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(context.strings.any)),
              // Keeps a saved value that is not one of the options.
              for (final km in {...maxDistanceOptions, ?_maxDistanceKm})
                DropdownMenuItem(
                  value: km,
                  child: Text(maxDistanceLabel(km, language: context.language)),
                ),
            ],
            onChanged: (value) => setState(() => _maxDistanceKm = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _minDealScore,
            decoration: InputDecoration(
              labelText: context.strings.minimumDealScore,
              border: OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(context.strings.any)),
              for (final min in minDealScoreOptions)
                DropdownMenuItem(
                  value: min,
                  child: Text(
                    dealScoreOptionLabel(min, language: context.language),
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _minDealScore = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _maxRiskScore,
            decoration: InputDecoration(
              labelText: context.strings.maximumRisk,
              border: OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(context.strings.any)),
              for (final max in maxRiskScoreOptions)
                DropdownMenuItem(
                  value: max,
                  child: Text(
                    riskCriterionLabel(max, language: context.language),
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _maxRiskScore = value),
          ),
          const SizedBox(height: 16),
          Text(
            context.strings.equipment,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final MapEntry(key: code, value: label) in extraLabels(
                language: context.language,
              ).entries)
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
            segments: [
              ButtonSegment(value: null, label: Text(context.strings.all)),
              ButtonSegment(
                value: SellerType.private,
                label: Text(context.strings.private),
              ),
              ButtonSegment(
                value: SellerType.dealer,
                label: Text(context.strings.dealerListingLabels),
              ),
            ],
            selected: {_sellerType},
            onSelectionChanged: (selection) =>
                setState(() => _sellerType = selection.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.strings.onlyYourColours),
            subtitle: Text(
              context.strings.eachModelSPreferredColoursSetInFollowed,
            ),
            value: _onlyMyColours,
            onChanged: (value) => setState(() => _onlyMyColours = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.strings.activeListingsOnly),
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
                  child: Text(context.strings.clear),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_build()),
                  child: Text(context.strings.apply),
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
