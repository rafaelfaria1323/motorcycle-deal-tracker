import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/entities/motorcycle_option.dart';
import '../../domain/entities/saved_search.dart';
import '../cubit/listings_cubit.dart';
import '../cubit/listings_state.dart';
import '../cubit/saved_searches_cubit.dart';
import '../cubit/saved_searches_state.dart';
import '../saved_search_summary.dart';
import '../widgets/delete_saved_search_dialog.dart';
import '../widgets/edit_saved_search_sheet.dart';

class SavedSearchesPage extends StatelessWidget {
  const SavedSearchesPage({super.key});

  static String _matchLabel(int count) =>
      count == 1 ? '1 oferta' : '$count ofertas';

  Future<void> _apply(BuildContext context, SavedSearch search) async {
    final listings = getIt<ListingsCubit>();
    // Only matters when the app was opened directly on this tab.
    if (listings.state.status == ListingsStatus.initial) {
      await listings.load();
    }
    unawaited(listings.applyFilters(search.filters));
    if (context.mounted) context.go(AppRoutes.deals);
  }

  Future<void> _edit(
    BuildContext context,
    SavedSearch search,
    List<MotorcycleOption> motorcycles,
  ) async {
    final cubit = context.read<SavedSearchesCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final edited = await showEditSavedSearchSheet(
      context,
      search: search,
      motorcycles: motorcycles,
    );
    if (edited == null) return;

    final saved = await cubit.update(edited);
    showMessage(
      messenger,
      saved ? 'Pesquisa atualizada' : 'Não foi possível atualizar a pesquisa',
    );
  }

  Future<void> _create(
    BuildContext context,
    List<MotorcycleOption> motorcycles,
  ) async {
    final cubit = context.read<SavedSearchesCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final draft = await showEditSavedSearchSheet(
      context,
      search: SavedSearch.draft(),
      motorcycles: motorcycles,
    );
    if (draft == null) return;

    final saved = await cubit.createFrom(draft);
    showMessage(
      messenger,
      saved ? 'Pesquisa guardada' : 'Não foi possível guardar a pesquisa',
    );
  }

  Future<void> _delete(BuildContext context, SavedSearch search) async {
    final cubit = context.read<SavedSearchesCubit>();
    final messenger = ScaffoldMessenger.of(context);

    if (!await confirmDeleteSavedSearch(context, search)) return;

    final deleted = await cubit.delete(search.id);
    showMessage(
      messenger,
      deleted ? 'Pesquisa eliminada' : 'Não foi possível eliminar a pesquisa',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pesquisas')),
      floatingActionButton: BlocBuilder<SavedSearchesCubit, SavedSearchesState>(
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.searches.isEmpty != current.searches.isEmpty ||
            previous.motorcycles != current.motorcycles,
        // With no searches yet the empty screen has its own button.
        builder: (context, state) =>
            state.status == SavedSearchesStatus.success &&
                state.searches.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: () => _create(context, state.motorcycles),
                icon: const Icon(Icons.add),
                label: const Text('Nova pesquisa'),
              )
            : const SizedBox.shrink(),
      ),
      body: BlocBuilder<SavedSearchesCubit, SavedSearchesState>(
        builder: (context, state) {
          switch (state.status) {
            case SavedSearchesStatus.initial:
            case SavedSearchesStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case SavedSearchesStatus.failure:
              return StateMessage(
                icon: Icons.cloud_off,
                title: 'Não foi possível carregar as pesquisas',
                message: 'Verifique a ligação e tente novamente.',
                actionLabel: 'Tentar novamente',
                onAction: () => context.read<SavedSearchesCubit>().load(),
              );
            case SavedSearchesStatus.success:
              if (state.searches.isEmpty) {
                return StateMessage(
                  icon: Icons.bookmark_border,
                  title: 'Ainda não tem pesquisas guardadas',
                  message:
                      'Crie uma pesquisa e avisamos quando surgir uma oferta '
                      'que lhe interesse.',
                  actionLabel: 'Nova pesquisa',
                  onAction: () => _create(context, state.motorcycles),
                );
              }
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView.builder(
                    // Room at the end so the button never covers a search.
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: state.searches.length,
                    itemBuilder: (context, index) {
                      final search = state.searches[index];
                      final matches = state.matchCounts[search.id] ?? 0;
                      return Card(
                        child: ListTile(
                          isThreeLine: true,
                          leading: const Icon(Icons.bookmark_outline),
                          title: Text(search.displayName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                summarizeFilters(
                                  search.filters,
                                  state.motorcycles,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _matchLabel(matches),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _apply(context, search),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _edit(context, search, state.motorcycles),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(context, search),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
          }
        },
      ),
    );
  }
}
