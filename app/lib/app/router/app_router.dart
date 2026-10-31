import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/collector_status/presentation/collection_status_page.dart';
import '../../features/listings/presentation/cubit/alerts_cubit.dart';
import '../../features/listings/presentation/cubit/favourites_cubit.dart';
import '../../features/listings/presentation/cubit/listing_detail_cubit.dart';
import '../../features/listings/presentation/cubit/listings_cubit.dart';
import '../../features/listings/presentation/cubit/saved_searches_cubit.dart';
import '../../features/listings/presentation/compare_text.dart';
import '../../features/listings/presentation/pages/alerts_page.dart';
import '../../features/valuation/presentation/pages/bike_value_page.dart';
import '../../features/listings/presentation/pages/compare_page.dart';
import '../../features/listings/presentation/pages/dashboard_page.dart';
import '../../features/listings/presentation/pages/favourites_page.dart';
import '../../features/listings/presentation/pages/listing_detail_page.dart';
import '../../features/listings/presentation/pages/model_market_page.dart';
import '../../features/listings/presentation/pages/saved_searches_page.dart';
import '../../features/listings/presentation/pages/tracked_models_page.dart';
import '../../features/listings/presentation/pages/weekly_summary_page.dart';
import '../../features/listings/presentation/photo_viewer_args.dart';
import '../../features/listings/presentation/widgets/photo_gallery.dart';
import '../../features/settings/presentation/accounts_page.dart';
import '../../features/settings/presentation/join_page.dart';
import '../../features/settings/presentation/more_page.dart';
import '../di/injection.dart';
import '../shell/app_shell.dart';
import 'app_routes.dart';

/// The navigator above the tabs: a listing and its photos open on it, so
/// they cover the tab bar and back returns to whichever tab opened them.
final _rootNavigator = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigator,
  initialLocation: AppRoutes.deals,
  redirect: (context, state) {
    final url = state.uri.toString();
    if (url.contains('error_code=') ||
        url.contains('access_token=') ||
        url.contains('error=')) {
      return AppRoutes.deals;
    }
    return null;
  },
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.deals,
              builder: (context, state) {
                final cubit = getIt<ListingsCubit>();
                if (cubit.state.status == .initial) cubit.load();
                // .value: the cubit is shared, so this route must not close it.
                return BlocProvider.value(
                  value: cubit,
                  child: const DashboardPage(),
                );
              },
              routes: [
                // Opened with `push` from any tab; from a notification
                // (`go`) the Ofertas list is beneath it.
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigator,
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return BlocProvider(
                      create: (_) => getIt<ListingDetailCubit>()..load(id),
                      child: ListingDetailPage(
                        listingId: id,
                        keepSection: state.extra == AppRoutes.fromList,
                      ),
                    );
                  },
                  routes: [
                    GoRoute(
                      path: 'photos',
                      parentNavigatorKey: _rootNavigator,
                      // A reloaded or typed address has no photos with it.
                      redirect: (context, state) =>
                          PhotoViewerArgs.fromExtra(state.extra) == null
                          ? AppRoutes.listingDetail(state.pathParameters['id']!)
                          : null,
                      pageBuilder: (context, state) => MaterialPage<void>(
                        key: state.pageKey,
                        fullscreenDialog: true,
                        child: FullScreenGallery(
                          listingId: state.pathParameters['id']!,
                          args: PhotoViewerArgs.fromExtra(state.extra)!,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.favourites,
              builder: (context, state) {
                // Opened directly (a reload), the shell may not have
                // loaded them yet.
                final cubit = getIt<FavouritesCubit>();
                if (cubit.state.status == .initial) cubit.load();
                return const FavouritesPage();
              },
            ),
          ],
        ),
        // Alertas and its second part, Pesquisas (F.9): two addresses in
        // one tab, switched in place by AlertsSegments without a slide.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.alerts,
              pageBuilder: (context, state) => NoTransitionPage<void>(
                key: state.pageKey,
                child: BlocProvider.value(
                  value: getIt<AlertsCubit>()..load(),
                  child: const AlertsPage(),
                ),
              ),
            ),
            GoRoute(
              path: AppRoutes.searches,
              pageBuilder: (context, state) => NoTransitionPage<void>(
                key: state.pageKey,
                child: BlocProvider.value(
                  value: getIt<SavedSearchesCubit>()..load(),
                  child: const SavedSearchesPage(),
                ),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.more,
              builder: (context, state) => const MorePage(),
            ),
          ],
        ),
      ],
    ),
    // Outside the shell: a full page with a back button, opened from Mais.
    GoRoute(
      path: AppRoutes.models,
      builder: (context, state) => const TrackedModelsPage(),
    ),
    GoRoute(
      path: AppRoutes.modelMarket,
      builder: (context, state) => const ModelMarketPage(),
    ),
    GoRoute(
      path: AppRoutes.bikeValue,
      builder: (context, state) =>
          BikeValuePage(requestId: state.uri.queryParameters['request']),
    ),
    GoRoute(
      path: AppRoutes.importBike,
      builder: (context, state) => const BikeValuePage(importing: true),
    ),
    GoRoute(
      path: AppRoutes.accounts,
      builder: (context, state) => const AccountsPage(),
    ),
    GoRoute(
      path: AppRoutes.collectionStatus,
      builder: (context, state) => const CollectionStatusPage(),
    ),
    // Also opened by a tap on the Monday notification (`/#/summary`).
    GoRoute(
      path: AppRoutes.summary,
      builder: (context, state) => const WeeklySummaryPage(),
    ),
    // An invite link (`/#/join?code=…`), opened from a message.
    GoRoute(
      path: AppRoutes.join,
      builder: (context, state) =>
          JoinPage(code: state.uri.queryParameters['code'] ?? ''),
    ),
    GoRoute(
      path: AppRoutes.comparePath,
      builder: (context, state) =>
          ComparePage(ids: parseCompareIds(state.uri.queryParameters['ids'])),
    ),
  ],
);
