import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/state_message.dart';
import '../cubit/favourites_cubit.dart';
import '../cubit/favourites_state.dart';
import '../../../listings/presentation/cubit/listing_card_preferences_cubit.dart';
import '../favourites_text.dart';
import '../similar_search.dart';
import '../widgets/favourite_sharing.dart';
import '../widgets/favourite_widgets.dart';
import '../widgets/viewing_checklist_card.dart';
import '../../../listings/presentation/widgets/listing_card.dart';
import '../../../saved_searches/presentation/widgets/save_search_dialog.dart';
import '../../../../core/localization/localizations.dart';

/// The shortlist: the listings the user starred, newest first, each with
/// their note. Removed ones stay, marked "Removido", with "Avisar-me de
/// uma parecida": a saved search for the next bike like it (N.84).
class const FavouritesPage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = getIt<FavouritesCubit>();
    return Scaffold(
      // A tab since F.9: no back arrow.
      appBar: AppBar(
        title: Text(context.strings.favourites),
        actions: [
          const SharedListsButton(),
          BlocBuilder<FavouritesCubit, FavouritesState>(
            bloc: cubit,
            builder: (context, state) => FavouritesMenu(
              favourites: [
                for (final f in state.favourites)
                  if (f.listing != null) f,
              ],
            ),
          ),
        ],
      ),
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
                          if (state.fromDevice) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.cloud_off, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.strings.favouritesFromDevice,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                              onFavourite: () =>
                                  toggleFavourite(context, f.listing!),
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
                                  if (favouriteChangesText(
                                        f.seen,
                                        f.listing!,
                                        language: context.language,
                                      )
                                      case final changes?) ...[
                                    FavouriteChangesLine(text: changes),
                                    const SizedBox(height: 4),
                                  ],
                                  FavouriteFacts(favourite: f),
                                  // Here too, not only on the ad's page: at
                                  // the viewing there may be no connection
                                  // to open it (N.66).
                                  TextButton.icon(
                                    onPressed: () => showViewingChecklist(
                                      context,
                                      f.listing!,
                                    ),
                                    icon: Icon(
                                      state.unsent.contains(f.listingId)
                                          ? Icons.cloud_off
                                          : Icons.checklist,
                                    ),
                                    label: Text(context.strings.forViewing),
                                  ),
                                  // Gone from the market: the search for
                                  // the next one like it (N.84).
                                  if (similarSearchFilters(f.listing!)
                                      case final similar?)
                                    TextButton.icon(
                                      onPressed: () => saveSearchWithName(
                                        context,
                                        similar,
                                        suggestion: similarSearchName(
                                          f.listing!,
                                          language: context.language,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.notifications_active_outlined,
                                      ),
                                      label: Text(
                                        context.strings.notifyMeOfSimilar,
                                      ),
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
