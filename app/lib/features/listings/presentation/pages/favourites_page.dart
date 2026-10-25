import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../../../core/widgets/state_message.dart';
import '../cubit/favourites_cubit.dart';
import '../cubit/favourites_state.dart';
import '../cubit/listing_card_preferences_cubit.dart';
import '../favourites_text.dart';
import '../viewing_checklist.dart';
import '../widgets/listing_card.dart';

/// The shortlist: the listings the user starred, newest first, each with
/// their note. Removed ones stay, marked "Removido".
class FavouritesPage extends StatelessWidget {
  const FavouritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = getIt<FavouritesCubit>();
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(fallback: AppRoutes.deals),
        title: const Text('Favoritos'),
      ),
      body: BlocBuilder<FavouritesCubit, FavouritesState>(
        bloc: cubit,
        builder: (context, state) {
          switch (state.status) {
            case FavouritesStatus.initial:
            case FavouritesStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case FavouritesStatus.failure:
              return StateMessage(
                icon: Icons.cloud_off,
                title: 'Não foi possível carregar os favoritos',
                message: 'Verifique a ligação e tente novamente.',
                actionLabel: 'Tentar novamente',
                onAction: cubit.load,
              );
            case FavouritesStatus.success:
              final favourites = [
                for (final f in state.favourites)
                  if (f.listing != null) f,
              ];
              if (favourites.isEmpty) {
                return const StateMessage(
                  icon: Icons.star_border,
                  title: 'Ainda não tem favoritos',
                  message:
                      'Toque na estrela de um anúncio para o guardar aqui, '
                      'com as suas notas. Avisamos quando baixar de preço '
                      'ou sair do mercado.',
                );
              }
              final theme = Theme.of(context);
              final muted = theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              );
              return BlocBuilder<
                ListingCardPreferencesCubit,
                ListingCardPreferencesState
              >(
                bloc: getIt<ListingCardPreferencesCubit>(),
                builder: (context, cards) => RefreshIndicator(
                  onRefresh: cubit.load,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(favouritesCountText(favourites), style: muted),
                          if (cards.status ==
                              ListingCardPreferencesStatus.failure)
                            TextButton.icon(
                              onPressed:
                                  getIt<ListingCardPreferencesCubit>().load,
                              icon: const Icon(Icons.refresh),
                              label: const Text(
                                'Não foi possível carregar os cartões. '
                                'Tentar novamente',
                              ),
                            ),
                          const SizedBox(height: 12),
                          for (final f in favourites) ...[
                            ListingCard(
                              listing: f.listing!,
                              favourite: true,
                              preferences: cards.preferences,
                              onTap: () => context.push(
                                AppRoutes.listingDetail(f.listingId),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (f.note != null) ...[
                                    Text(
                                      f.note!,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  if (f.checklist.isNotEmpty) ...[
                                    Text(
                                      checklistIssuesText(f.checklist) ??
                                          checklistSummaryText(f.checklist),
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  Text(favouriteSinceText(f), style: muted),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
          }
        },
      ),
    );
  }
}
