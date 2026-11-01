import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../listings/domain/entities/listing_filters.dart';
import '../../../listings/domain/entities/motorcycle_option.dart';
import '../../domain/entities/saved_search.dart';
import '../cubit/saved_searches_cubit.dart';
import '../saved_search_summary.dart';
import '../../../listings/presentation/widgets/filters_sheet.dart';
import '../../../../core/localization/localizations.dart';

Future<bool> editSavedSearch(
  BuildContext context, {
  required SavedSearch search,
  required SavedSearchesCubit cubit,
}) async {
  final messageStrings = context.strings;
  final messageLanguage = context.language;

  final messenger = ScaffoldMessenger.of(context);
  final edited = await showEditSavedSearchSheet(
    context,
    search: search,
    motorcycles: cubit.state.motorcycles,
  );
  if (edited == null || !context.mounted) return false;
  final same = savedSearchLike(
    cubit.state.searches,
    edited.filters,
    except: edited.id,
  );
  if (same != null) {
    showMessage(messenger, alreadySavedText(same, language: messageLanguage));
    return false;
  }

  final saved = await cubit.update(edited);
  if (messenger.mounted) {
    showMessage(
      messenger,
      saved
          ? messageStrings.searchUpdated
          : messageStrings.couldNotUpdateSearch,
    );
  }
  return saved;
}

/// Returns the edited search, or null if cancelled.
Future<SavedSearch?> showEditSavedSearchSheet(
  BuildContext context, {
  required SavedSearch search,
  required List<MotorcycleOption> motorcycles,
}) {
  return showModalBottomSheet<SavedSearch>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) =>
        EditSavedSearchSheet(search: search, motorcycles: motorcycles),
  );
}

class const EditSavedSearchSheet({
  required final SavedSearch search,
  required final List<MotorcycleOption> motorcycles,
  super.key,
}) extends StatefulWidget {
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
    final summary = summarizeFilters(
      _filters,
      widget.motorcycles,
      language: context.language,
    );

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
                widget.search.isDraft
                    ? context.strings.newSearch
                    : context.strings.editSearch,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                maxLength: 60,
                decoration: InputDecoration(labelText: context.strings.name),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? context.strings.enterName
                    : null,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.strings.criteria),
                subtitle: Text(
                  _criteriaMissing || summary.isEmpty
                      ? context.strings.chooseAtLeastOneCriterion
                      : summary,
                  style: _criteriaMissing ? AppTheme.errorText(context) : null,
                ),
                trailing: TextButton(
                  onPressed: _editCriteria,
                  child: Text(
                    _filters.hasCriteria
                        ? context.strings.change
                        : context.strings.choose,
                  ),
                ),
              ),
              const Divider(),
              Text(
                context.strings.notifyMeWhen,
                style: theme.textTheme.titleSmall,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.strings.newListingAppears),
                value: _notifyNewListing,
                onChanged: (v) => setState(() => _notifyNewListing = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.strings.priceDropsEditSavedSearchSheet),
                value: _notifyPriceReduction,
                onChanged: (v) => setState(() => _notifyPriceReduction = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.strings.thereIsExcellentOpportunity),
                value: _notifyExcellentDeal,
                onChanged: (v) => setState(() => _notifyExcellentDeal = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.strings.listingIsRemoved),
                value: _notifyListingRemoved,
                onChanged: (v) => setState(() => _notifyListingRemoved = v),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.strings.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    child: Text(context.strings.save),
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
