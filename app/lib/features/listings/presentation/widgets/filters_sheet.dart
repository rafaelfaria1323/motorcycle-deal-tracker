import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/collapsible_section.dart';
import '../../../settings/presentation/home_place_cubit.dart';
import '../../../settings/presentation/home_place_tile.dart';
import '../../domain/entities/districts.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_filters.dart';
import '../../domain/entities/motorcycle_option.dart';
import '../filter_fields_text.dart';
import '../filter_sections_text.dart';
import '../../../saved_searches/presentation/saved_search_summary.dart';
import '../score_criteria.dart';
import '../score_explanation.dart';
import '../../../../core/localization/localizations.dart';

class const FiltersSheet({
  required final ListingFilters initial,
  required final List<MotorcycleOption> motorcycles,
  super.key,
}) extends StatefulWidget {
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
  late String? _district = widget.initial.district;

  late final _year = TextEditingController(
    text: widget.initial.minYear?.toString() ?? '',
  );
  late final _maxYear = TextEditingController(
    text: widget.initial.maxYear?.toString() ?? '',
  );
  late final _minPrice = TextEditingController(
    text: widget.initial.minPrice?.toStringAsFixed(0) ?? '',
  );
  late final _price = TextEditingController(
    text: widget.initial.maxPrice?.toStringAsFixed(0) ?? '',
  );
  late final _mileage = TextEditingController(
    text: widget.initial.maxMileage?.toString() ?? '',
  );

  @override
  void dispose() {
    _year.dispose();
    _maxYear.dispose();
    _minPrice.dispose();
    _price.dispose();
    _mileage.dispose();
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
      maxYear: parseWholeNumberField(_maxYear.text),
      minPrice: parsePriceField(_minPrice.text),
      maxPrice: parsePriceField(_price.text),
      maxMileage: parseWholeNumberField(_mileage.text),
      district: _district,
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
    final language = context.language;
    final placeChoices = [
      ?_district,
      if (_maxDistanceKm case final km?)
        maxDistanceLabel(km, language: language),
    ];
    final scoreChoices = [
      if (_minDealScore case final min?)
        dealScoreOptionLabel(min, language: language),
      if (_maxRiskScore case final max?)
        riskCriterionLabel(max, language: language),
    ];
    final extras = extraLabels(language: language);

    // The buttons stay below the scrolling choices, so applying never
    // needs a scroll to the end.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
            child: Row(
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
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  // Each range on one row: from, then to.
                  _RangeFields(
                    from: _year,
                    fromLabel: context.strings.earliestYear,
                    to: _maxYear,
                    toLabel: context.strings.latestYear,
                  ),
                  const SizedBox(height: 12),
                  _RangeFields(
                    from: _minPrice,
                    fromLabel: context.strings.minimumPriceEUR,
                    to: _price,
                    toLabel: context.strings.maximumPriceEUR,
                  ),
                  const SizedBox(height: 12),
                  _NumberField(
                    controller: _mileage,
                    label: context.strings.maximumMileageKm,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<SellerType?>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: null,
                        label: Text(context.strings.all),
                      ),
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
                  const SizedBox(height: 4),
                  CollapsibleSection(
                    title: context.strings.models,
                    summary: chosenSummary(
                      [
                        for (final m in widget.motorcycles)
                          if (_motorcycleIds.contains(m.id)) m.model,
                      ],
                      none: context.strings.all,
                      language: language,
                    ),
                    active: _motorcycleIds.isNotEmpty,
                    children: [
                      Text(
                        context.strings.chooseOneOrMoreLeaveEmptyForAll,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      for (final MapEntry(key: brand, value: models)
                          in modelsByBrand(widget.motorcycles).entries) ...[
                        const SizedBox(height: 8),
                        Text(
                          brand,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
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
                    ],
                  ),
                  CollapsibleSection(
                    title: context.strings.filterPlaceSection,
                    summary: chosenSummary(
                      placeChoices,
                      none: context.strings.any,
                      language: language,
                    ),
                    active: placeChoices.isNotEmpty,
                    children: [
                      // A list, not free text: the ads' towns are looked up
                      // in their district (`listings.district`).
                      DropdownButtonFormField<String?>(
                        initialValue: _district,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: context.strings.district,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(context.strings.any),
                          ),
                          for (final district in portugueseDistricts)
                            DropdownMenuItem(
                              value: district,
                              child: Text(district),
                            ),
                        ],
                        onChanged: (value) => setState(() => _district = value),
                      ),
                      const SizedBox(height: 12),
                      BlocBuilder<HomePlaceCubit, HomePlaceState>(
                        bloc: getIt<HomePlaceCubit>(),
                        builder: (context, home) => _DistanceField(
                          value: _maxDistanceKm,
                          noHome: home.noHome,
                          onChanged: (value) =>
                              setState(() => _maxDistanceKm = value),
                        ),
                      ),
                    ],
                  ),
                  CollapsibleSection(
                    title: context.strings.filterScoreSection,
                    summary: chosenSummary(
                      scoreChoices,
                      none: context.strings.any,
                      language: language,
                    ),
                    active: scoreChoices.isNotEmpty,
                    children: [
                      DropdownButtonFormField<int?>(
                        initialValue: _minDealScore,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: context.strings.minimumDealScore,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(context.strings.any),
                          ),
                          for (final min in minDealScoreOptions)
                            DropdownMenuItem(
                              value: min,
                              child: Text(
                                dealScoreOptionLabel(min, language: language),
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _minDealScore = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        initialValue: _maxRiskScore,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: context.strings.maximumRisk,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(context.strings.any),
                          ),
                          for (final max in maxRiskScoreOptions)
                            DropdownMenuItem(
                              value: max,
                              child: Text(
                                riskCriterionLabel(max, language: language),
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _maxRiskScore = value),
                      ),
                    ],
                  ),
                  CollapsibleSection(
                    title: context.strings.equipment,
                    summary: chosenSummary(
                      [
                        for (final MapEntry(key: code, value: label)
                            in extras.entries)
                          if (_extras.contains(code)) label,
                      ],
                      none: context.strings.any,
                      language: language,
                    ),
                    active: _extras.isNotEmpty,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final MapEntry(key: code, value: label)
                              in extras.entries)
                            FilterChip(
                              label: Text(label),
                              selected: _extras.contains(code),
                              onSelected: (selected) => setState(
                                () => selected
                                    ? _extras.add(code)
                                    : _extras.remove(code),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.strings.onlyYourColours),
                    subtitle: Text(
                      context.strings.eachModelSPreferredColoursSetInFollowed,
                    ),
                    value: _onlyMyColours,
                    onChanged: (value) =>
                        setState(() => _onlyMyColours = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.strings.activeListingsOnly),
                    value: _activeOnly,
                    onChanged: (value) => setState(() => _activeOnly = value),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
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
          ),
        ],
      ),
    );
  }
}

/// "Distância máxima". Without a home no listing has a distance, so it
/// would match nothing: it is off (unless a distance is already chosen, so
/// it can be cleared) and offers to set the home.
class const _DistanceField({
  required final int? value,
  required final bool noHome,
  required final ValueChanged<int?> onChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final language = context.language;
    final off = noHome && value == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int?>(
          // A new key when it turns on, as the field keeps its first value.
          key: ValueKey(noHome),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.strings.maximumDistance,
            helperText: noHome
                ? context.strings.setHomeToFilterByDistance
                : context.strings.fromYourHomeLocationInMore,
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(value: null, child: Text(context.strings.any)),
            // Keeps a saved value that is not one of the options.
            for (final km in {...maxDistanceOptions, ?value})
              DropdownMenuItem(
                value: km,
                child: Text(maxDistanceLabel(km, language: language)),
              ),
          ],
          onChanged: off ? null : onChanged,
        ),
        if (noHome)
          TextButton.icon(
            onPressed: () => unawaited(pickHomePlace(context)),
            icon: const Icon(Icons.home_outlined),
            label: Text(context.strings.setHomePlace),
          ),
      ],
    );
  }
}

class const _NumberField({
  required final TextEditingController controller,
  required final String label,
}) extends StatelessWidget {
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

/// A range on one row: its lower bound, then its upper one.
class const _RangeFields({
  required final TextEditingController from,
  required final String fromLabel,
  required final TextEditingController to,
  required final String toLabel,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _NumberField(controller: from, label: fromLabel),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _NumberField(controller: to, label: toLabel),
        ),
      ],
    );
  }
}
