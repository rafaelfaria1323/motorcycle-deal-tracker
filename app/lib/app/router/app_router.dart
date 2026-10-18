import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/listings/presentation/cubit/alerts_cubit.dart';
import '../../features/listings/presentation/cubit/listing_detail_cubit.dart';
import '../../features/listings/presentation/cubit/listings_cubit.dart';
import '../../features/listings/presentation/cubit/listings_state.dart';
import '../../features/listings/presentation/cubit/saved_searches_cubit.dart';
import '../../features/listings/presentation/pages/alerts_page.dart';
import '../../features/listings/presentation/pages/dashboard_page.dart';
import '../../features/listings/presentation/pages/listing_detail_page.dart';
import '../../features/listings/presentation/pages/saved_searches_page.dart';
import '../di/injection.dart';
import '../shell/app_shell.dart';
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
              builder: (context, state) {
                final cubit = getIt<ListingsCubit>();
                if (cubit.state.status == ListingsStatus.initial) cubit.load();
                // .value: the cubit is shared, so this route must not close it.
                return BlocProvider.value(
                  value: cubit,
                  child: const DashboardPage(),
                );
              },
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
              builder: (context, state) => BlocProvider.value(
                value: getIt<AlertsCubit>()..load(),
                child: const AlertsPage(),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);
