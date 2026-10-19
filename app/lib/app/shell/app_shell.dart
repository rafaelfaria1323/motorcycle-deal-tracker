import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/listings/presentation/cubit/alerts_cubit.dart';
import '../../features/listings/presentation/cubit/alerts_state.dart';
import '../di/injection.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _alerts = getIt<AlertsCubit>();

  // The unread count on the Alertas tab needs the alerts from the start,
  // and again when the app comes back to the screen (new collections run
  // while it is in the background).
  late final AppLifecycleListener _lifecycle;

  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _alerts.load);
    if (_alerts.state.status == AlertsStatus.initial) _alerts.load();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  static const _wideBreakpoint = 840.0;
  static const _maxContentWidth = 1200.0;

  static const _alertsIndex = 2;

  static const _destinations = [
    _Destination('Ofertas', Icons.local_offer_outlined, Icons.local_offer),
    _Destination('Pesquisas', Icons.bookmark_border, Icons.bookmark),
    _Destination('Alertas', Icons.notifications_outlined, Icons.notifications),
    _Destination('Mais', Icons.more_horiz, Icons.more_horiz),
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
      // Tapping the current tab returns to its first screen.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

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
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onSelect,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final (i, d) in _destinations.indexed)
                  NavigationRailDestination(
                    icon: _icon(i, selected: false),
                    selectedIcon: _icon(i, selected: true),
                    label: Text(d.label),
                  ),
              ],
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

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
