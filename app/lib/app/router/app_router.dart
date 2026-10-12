import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/listings/presentation/cubit/listings_cubit.dart';
import '../../features/listings/presentation/pages/dashboard_page.dart';
import '../di/injection.dart';
import '../shell/app_shell.dart';
import '../shell/placeholder_page.dart';

abstract final class AppRoutes {
  static const deals = '/deals';
  static const searches = '/searches';
  static const alerts = '/alerts';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.deals,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.deals,
              builder: (context, state) =>
                  BlocProvider(create: (_) => getIt<ListingsCubit>()..load(), child: const DashboardPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.searches,
              builder: (context, state) => const PlaceholderPage(title: 'Pesquisas'),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.alerts,
              builder: (context, state) => const PlaceholderPage(title: 'Alertas'),
            ),
          ],
        ),
      ],
    ),
  ],
);
