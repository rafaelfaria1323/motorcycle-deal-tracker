import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_brand.dart';
import '../../features/listings/presentation/cubit/alerts_cubit.dart';
import '../../features/listings/presentation/cubit/alerts_state.dart';
import '../../features/listings/presentation/cubit/favourites_cubit.dart';
import '../../features/listings/presentation/cubit/listings_cubit.dart';
import '../../features/settings/presentation/home_place_cubit.dart';
import '../di/injection.dart';
import '../../core/localization/localizations.dart';

class const AppShell({
  required final StatefulNavigationShell navigationShell,
  super.key,
}) extends StatefulWidget {
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _alerts = getIt<AlertsCubit>();
  final _favourites = getIt<FavouritesCubit>();
  final _home = getIt<HomePlaceCubit>();
  final _listings = getIt<ListingsCubit>();

  // The unread count on the Alertas tab needs the alerts from the start,
  // and again when the app comes back to the screen (new collections run
  // while it is in the background). The stars on the cards need the
  // favourites from the start too, and the sort menu and the filters the
  // home (without one, the distance options say how to set it). Ofertas,
  // once its list is a while old, counts the ads found since (F.7).
  late final AppLifecycleListener _lifecycle;

  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _alerts.load();
        _listings.checkForNew();
      },
    );
    if (_alerts.state.status == .initial) _alerts.load();
    if (_favourites.state.status == .initial) {
      _favourites.load();
    }
    if (_home.state.status == .initial) _home.load();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  static const _wideBreakpoint = 840.0;
  static const _maxContentWidth = 1200.0;

  static const _alertsIndex = 2;

  List<_Destination> get _destinations => [
    _Destination(
      context.strings.deals,
      Icons.local_offer_outlined,
      Icons.local_offer,
    ),
    _Destination(context.strings.favourites, Icons.star_border, Icons.star),
    _Destination(
      context.strings.alerts,
      Icons.notifications_outlined,
      Icons.notifications,
    ),
    _Destination(context.strings.more, Icons.more_horiz, Icons.more_horiz),
  ];

  /// The tab icon, with the unread count on Alertas.
  Widget _icon(int index, {required bool selected}) {
    final d = _destinations[index];
    final icon = Icon(selected ? d.selectedIcon : d.icon);
    if (index != _alertsIndex) return icon;

    return BlocBuilder<AlertsCubit, AlertsState>(
      bloc: _alerts,
      buildWhen: (previous, current) =>
          previous.unreadCount != current.unreadCount,
      builder: (context, state) => Badge(
        isLabelVisible: state.unreadCount > 0,
        label: Text(state.unreadCount > 99 ? '99+' : '${state.unreadCount}'),
        child: icon,
      ),
    );
  }

  void _onSelect(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the current tab returns to its first screen. Alertas
      // always opens on the alerts, not on Pesquisas where it was left:
      // its badge counts the alerts (F.9).
      initialLocation:
          index == navigationShell.currentIndex || index == _alertsIndex,
    );
  }

  /// Android's back (button or edge swipe) on another tab returns to
  /// Ofertas, as Android apps with tabs do, instead of closing the app;
  /// on Ofertas it closes the app. The browser's back works on its own
  /// history and never reaches this.
  Widget _backToFirstTab(Widget child) => PopScope(
    canPop: navigationShell.currentIndex == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) navigationShell.goBranch(0);
    },
    child: child,
  );

  @override
  Widget build(BuildContext context) => _backToFirstTab(_layout(context));

  Widget _layout(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= _wideBreakpoint;
    final extended =
        width >= 1180 && MediaQuery.textScalerOf(context).scale(16) <= 20;

    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: navigationShell,
      ),
    );

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              right: false,
              child: NavigationRail(
                extended: extended,
                minWidth: 92,
                minExtendedWidth: 224,
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _onSelect,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 24, 12, 40),
                  child: AppBrand(compact: !extended),
                ),
                destinations: [
                  for (final (i, d) in _destinations.indexed)
                    NavigationRailDestination(
                      icon: _icon(i, selected: false),
                      selectedIcon: _icon(i, selected: true),
                      label: Text(d.label),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      body: content,
      // A hairline separates the bar from the page instead of a shadow.
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onSelect,
          destinations: [
            for (final (i, d) in _destinations.indexed)
              NavigationDestination(
                icon: _icon(i, selected: false),
                selectedIcon: _icon(i, selected: true),
                label: d.label,
              ),
          ],
        ),
      ),
    );
  }
}

class const _Destination(
  final String label,
  final IconData icon,
  final IconData selectedIcon,
);
