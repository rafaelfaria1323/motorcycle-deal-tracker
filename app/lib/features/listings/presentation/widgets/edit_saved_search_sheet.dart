import 'package:flutter/material.dart';

import '../../domain/entities/listing_filters.dart';
import '../../domain/entities/motorcycle_option.dart';
import '../../domain/entities/saved_search.dart';
import '../saved_search_summary.dart';
import 'filters_sheet.dart';

/// Returns the edited search, or null if cancelled.
Future<SavedSearch?> showEditSavedSearchSheet(
  BuildContext context, {
  required SavedSearch search,
  required List<MotorcycleOption> motorcycles,
}) {
  return showModalBottomSheet<SavedSearch>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) =>
        EditSavedSearchSheet(search: search, motorcycles: motorcycles),
  );
}

class EditSavedSearchSheet extends StatefulWidget {
  const EditSavedSearchSheet({
    required this.search,
    required this.motorcycles,
    super.key,
  });

  final SavedSearch search;
  final List<MotorcycleOption> motorcycles;

  @override
  State<EditSavedSearchSheet> createState() => _EditSavedSearchSheetState();
}

class _EditSavedSearchSheetState extends State<EditSavedSearchSheet> {
  late final _nameController = TextEditingController(
    text: widget.search.name ?? '',
  );
  final _formKey = GlobalKey<FormState>();

  late ListingFilters _filters = widget.search.filters;
  late bool _notifyNewListing = widget.search.notifyNewListing;
  late bool _notifyPriceReduction = widget.search.notifyPriceReduction;
  late bool _notifyExcellentDeal = widget.search.notifyExcellentDeal;
  late bool _notifyListingRemoved = widget.search.notifyListingRemoved;

  bool _criteriaMissing = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _editCriteria() async {
    final result = await showModalBottomSheet<ListingFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) =>
          FiltersSheet(initial: _filters, motorcycles: widget.motorcycles),
    );
    if (result == null) return;
    setState(() {
      // The live-only switch is not part of a saved search.
      _filters = result.criteriaOnly;
      _criteriaMissing = !_filters.hasCriteria;
    });
  }

  void _submit() {
    final nameOk = _formKey.currentState!.validate();
    final criteriaOk = _filters.hasCriteria;
    setState(() => _criteriaMissing = !criteriaOk);
    if (!nameOk || !criteriaOk) return;

    Navigator.of(context).pop(
      widget.search.copyWith(
        name: _nameController.text.trim(),
        filters: _filters,
        notifyNewListing: _notifyNewListing,
        notifyPriceReduction: _notifyPriceReduction,
        notifyExcellentDeal: _notifyExcellentDeal,
        notifyListingRemoved: _notifyListingRemoved,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = summarizeFilters(_filters, widget.motorcycles);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.search.isDraft ? 'Nova pesquisa' : 'Editar pesquisa',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Indique um nome'
                    : null,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Critérios'),
                subtitle: Text(
                  _criteriaMissing || summary.isEmpty
                      ? 'Escolha pelo menos um critério'
                      : summary,
                  style: _criteriaMissing
                      ? TextStyle(color: theme.colorScheme.error)
                      : null,
                ),
                trailing: TextButton(
                  onPressed: _editCriteria,
                  child: Text(_filters.hasCriteria ? 'Alterar' : 'Escolher'),
                ),
              ),
              const Divider(),
              Text('Avisar-me quando', style: theme.textTheme.titleSmall),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Surgir um anúncio novo'),
                value: _notifyNewListing,
                onChanged: (v) => setState(() => _notifyNewListing = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('O preço baixar'),
                value: _notifyPriceReduction,
                onChanged: (v) => setState(() => _notifyPriceReduction = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Houver uma excelente oportunidade'),
                value: _notifyExcellentDeal,
                onChanged: (v) => setState(() => _notifyExcellentDeal = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Um anúncio for removido'),
                value: _notifyListingRemoved,
                onChanged: (v) => setState(() => _notifyListingRemoved = v),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
