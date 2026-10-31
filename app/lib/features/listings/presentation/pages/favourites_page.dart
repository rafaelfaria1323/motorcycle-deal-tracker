import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/state_message.dart';
import '../cubit/favourites_cubit.dart';
import '../cubit/favourites_state.dart';
import '../cubit/listing_card_preferences_cubit.dart';
import '../favourites_text.dart';
import '../viewing_checklist.dart';
import '../widgets/listing_card.dart';
import '../../../../core/localization/localizations.dart';

/// The shortlist: the listings the user starred, newest first, each with
/// their note. Removed ones stay, marked "Removido".
class const FavouritesPage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = getIt<FavouritesCubit>();
    return Scaffold(
      // A tab since F.9: no back arrow.
      appBar: AppBar(title: Text(context.strings.favourites)),
      body: BlocBuilder<FavouritesCubit, FavouritesState>(
        bloc: cubit,
        builder: (context, state) {
          switch (state.status) {
            case .initial:
            case .loading:
              return const Center(child: CircularProgressIndicator());
            case .failure:
              return StateMessage(
                icon: Icons.cloud_off,
                title: context.strings.couldNotLoadFavourites,
                message: context.strings.checkYourConnectionAndTryAgain,
                actionLabel: context.strings.retry,
                onAction: cubit.load,
              );
            case .success:
              final favourites = [
                for (final f in state.favourites)
                  if (f.listing != null) f,
              ];
              if (favourites.isEmpty) {
                return StateMessage(
                  icon: Icons.star_border,
                  title: context.strings.youHaveNoFavouritesYet,
                  message: context.strings.tapListingSStarToSaveItHere,
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
                          Text(
                            favouritesCountText(
                              favourites,
                              language: context.language,
                            ),
                            style: muted,
                          ),
                          if (cards.status ==
                              ListingCardPreferencesStatus.failure)
                            TextButton.icon(
                              onPressed:
                                  getIt<ListingCardPreferencesCubit>().load,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                context
                                    .strings
                                    .couldNotLoadListingCardsTryAgain,
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
                                extra: AppRoutes.fromList,
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
                                      checklistIssuesText(
                                            f.checklist,
                                            language: context.language,
                                          ) ??
                                          checklistSummaryText(
                                            f.checklist,
                                            language: context.language,
                                          ),
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  Text(
                                    favouriteSinceText(
                                      f,
                                      language: context.language,
                                    ),
                                    style: muted,
                                  ),
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
