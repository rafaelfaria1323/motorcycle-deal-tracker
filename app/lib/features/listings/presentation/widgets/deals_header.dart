import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/page_intro.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../saved_searches/domain/entities/saved_search.dart';
import '../../../saved_searches/presentation/cubit/saved_searches_cubit.dart';
import '../../../saved_searches/presentation/cubit/saved_searches_state.dart';
import '../../../saved_searches/presentation/saved_search_summary.dart';
import '../../../saved_searches/presentation/widgets/save_search_dialog.dart';
import '../../../settings/presentation/home_place_cubit.dart';
import '../../../settings/presentation/home_place_tile.dart';
import '../../domain/entities/listing_filters.dart';
import '../../domain/entities/listing_sort.dart';
import '../cubit/listings_cubit.dart';
import '../cubit/listings_state.dart';
import '../dashboard_text.dart';
import '../listing_labels.dart';
import 'filters_sheet.dart';

/// The top of Ofertas: the intro on an empty list, then Filtros, the sort
/// and the count, then the chosen filters with "Guardar pesquisa".
class const DealsHeader({required final ListingsState state, super.key})
    extends StatelessWidget {
  Future<void> _openFilters(BuildContext context) async {
    final cubit = context.read<ListingsCubit>();
    final result = await showModalBottomSheet<ListingFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => FiltersSheet(
        initial: cubit.state.filters,
        motorcycles: cubit.state.motorcycles,
      ),
    );
    if (result != null) unawaited(cubit.applyFilters(result));
  }

  Future<void> _saveSearch(BuildContext context) async {
    final messageStrings = context.strings;
    final messageLanguage = context.language;

    final state = context.read<ListingsCubit>().state;
    final filters = state.filters;
    final messenger = ScaffoldMessenger.of(context);
    final searches = getIt<SavedSearchesCubit>();

    // The list loads with the Pesquisas tab: without it the same search
    // could be saved again.
    if (searches.state.status != .success) {
      await searches.load();
    }
    if (savedSearchLike(searches.state.searches, filters) case final same?) {
      showMessage(messenger, alreadySavedText(same, language: messageLanguage));
      return;
    }
    if (!context.mounted) return;

    final name = await showSaveSearchDialog(
      context,
      suggestion: summarizeFilters(
        filters,
        state.motorcycles,
        language: messageLanguage,
      ),
    );
    if (name == null) return;

    final saved = await searches.create(name, filters);
    showMessage(
      messenger,
      saved ? messageStrings.searchSaved : messageStrings.couldNotSaveSearch,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ListingsCubit>();
    final chips = filterChips(
      state.filters,
      state.motorcycles,
      language: context.language,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Opened several times a day: the intro only welcomes an empty
        // list, the ads start at once.
        if (state.status == .success &&
            state.listings.isEmpty &&
            state.filters.appliedCount == 0) ...[
          PageIntro(
            eyebrow: context.strings.yourMotorcycleRadar,
            title: context.strings.yourNextBikeStartsHere,
            description: context.strings.dealsIntro,
          ),
          const SizedBox(height: 24),
        ],
        _OffersToolbar(state: state, onFilters: () => _openFilters(context)),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final chip in chips)
                InputChip(
                  label: Text(chip.label),
                  onDeleted: () => cubit.applyFilters(chip.without),
                  deleteButtonTooltipMessage: context.strings.removeFilter,
                ),
              if (chips.length > 1)
                ActionChip(
                  label: Text(context.strings.clearAll),
                  onPressed: () => cubit.applyFilters(ListingFilters.empty),
                ),
              // Saving belongs to the chosen filters: without a criterion
              // there is nothing to save.
              if (state.filters.hasCriteria)
                BlocBuilder<SavedSearchesCubit, SavedSearchesState>(
                  bloc: getIt<SavedSearchesCubit>(),
                  builder: (context, searches) => _SaveSearchButton(
                    saved: savedSearchLike(searches.searches, state.filters),
                    onSave: () => _saveSearch(context),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Applies [sort]; "Mais perto" without a home first asks for one, and
/// stays unapplied if none was set.
Future<void> _applySort(BuildContext context, ListingSort sort) async {
  final listings = context.read<ListingsCubit>();
  if (sort == .nearest &&
      getIt<HomePlaceCubit>().state.noHome &&
      !await pickHomePlace(context)) {
    return;
  }
  await listings.applySort(sort);
}

/// Filtros, the sort and the count, on one row where they fit (most
/// phones: the count then takes a short line of its own).
class const _OffersToolbar({
  required final ListingsState state,
  required final VoidCallback onFilters,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: onFilters,
            icon: Badge(
              isLabelVisible: state.filters.appliedCount > 0,
              label: Text('${state.filters.appliedCount}'),
              child: const Icon(Icons.tune, size: 18),
            ),
            label: Text(context.strings.filters),
          ),
          PopupMenuButton<ListingSort>(
            tooltip: context.strings.sort,
            initialValue: state.sort,
            onSelected: (sort) => unawaited(_applySort(context, sort)),
            itemBuilder: (localizationContext) {
              // Without a home no listing has a distance: "Mais perto"
              // says so, and picking it asks for the home first.
              final noHome = getIt<HomePlaceCubit>().state.noHome;
              return [
                for (final sort in ListingSort.values)
                  CheckedPopupMenuItem(
                    value: sort,
                    checked: sort == state.sort,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sort.label(language: localizationContext.language),
                        ),
                        if (sort == .nearest && noHome)
                          Text(
                            localizationContext.strings.nearestNeedsHome,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
              ];
            },
            child: Container(
              constraints: BoxConstraints(
                minHeight: 48,
                maxWidth: constraints.maxWidth,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                border: Border.all(color: scheme.outline),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      state.sort.label(language: context.language),
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
          if (state.status == .success && state.listings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                listingsResultsText(
                  state.listings.length,
                  hasMore: state.hasMore,
                  language: context.language,
                ),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Guardar pesquisa", or "Pesquisa guardada" (opens Pesquisas) when these
/// filters already are the saved search [saved].
class const _SaveSearchButton({
  required final SavedSearch? saved,
  required final VoidCallback onSave,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => saved == null
      ? TextButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
          label: Text(context.strings.saveSearch),
        )
      : TextButton.icon(
          onPressed: () => context.go(AppRoutes.searches),
          icon: const Icon(Icons.bookmark_added, size: 18),
          label: Text(context.strings.searchSaved),
        );
}
