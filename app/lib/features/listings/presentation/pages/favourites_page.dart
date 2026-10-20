import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/state_message.dart';
import '../cubit/favourites_cubit.dart';
import '../cubit/favourites_state.dart';
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
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.deals),
        ),
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
              return RefreshIndicator(
                onRefresh: cubit.load,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(favouritesCountText(favourites), style: muted),
                        const SizedBox(height: 12),
                        for (final f in favourites) ...[
                          SizedBox(
                            height: ListingCard.height,
                            child: ListingCard(
                              listing: f.listing!,
                              favourite: true,
                              onTap: () => context.go(
                                AppRoutes.listingDetail(f.listingId),
                              ),
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
              );
          }
        },
      ),
    );
  }
}
