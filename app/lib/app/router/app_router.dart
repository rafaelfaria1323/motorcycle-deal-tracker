import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/listings/presentation/cubit/listing_detail_cubit.dart';
import '../../features/listings/presentation/cubit/listings_cubit.dart';
import '../../features/listings/presentation/cubit/saved_searches_cubit.dart';
import '../../features/listings/presentation/pages/dashboard_page.dart';
import '../../features/listings/presentation/pages/listing_detail_page.dart';
import '../../features/listings/presentation/pages/saved_searches_page.dart';
import '../di/injection.dart';
import '../shell/app_shell.dart';
import '../shell/placeholder_page.dart';
import 'app_routes.dart';

final appRouter = GoRouter(
  initialLocation: AppRoutes.deals,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.deals,
              builder: (context, state) => BlocProvider(
                create: (_) => getIt<ListingsCubit>()..load(),
                child: const DashboardPage(),
              ),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return BlocProvider(
                      create: (_) => getIt<ListingDetailCubit>()..load(id),
                      child: ListingDetailPage(listingId: id),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.searches,

              builder: (context, state) => BlocProvider.value(
                value: getIt<SavedSearchesCubit>()..load(),
                child: const SavedSearchesPage(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.alerts,
              builder: (context, state) =>
                  const PlaceholderPage(title: 'Alertas'),
            ),
          ],
        ),
      ],
    ),
  ],
);
