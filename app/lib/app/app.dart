import 'package:flutter/material.dart';

import '../core/platform/home_screen_app.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

const _title = 'Motorcycle Deal Tracker';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: _title,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      // On the web the browser bar (the iPhone status bar of the home-screen
      // app) takes this colour: the background of the current light or dark
      // theme, so it blends with the page. The inner Title runs after
      // MaterialApp's own, which would otherwise set the primary colour.
      builder: (context, child) => Title(
        title: _title,
        color: Theme.of(context).colorScheme.surface,
        child: _withHomeBarInset(context, child ?? const SizedBox.shrink()),
      ),
    );
  }

  /// In the iPhone home-screen app, a bottom safe area for the home bar, so
  /// the tab bar (and every SafeArea at the bottom) stays above it.
  static Widget _withHomeBarInset(BuildContext context, Widget child) {
    if (!isIphoneHomeScreenAppWithHomeBar) return child;
    final media = MediaQuery.of(context);
    if (media.viewPadding.bottom >= homeBarInset) return child;
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(bottom: homeBarInset),
        viewPadding: media.viewPadding.copyWith(bottom: homeBarInset),
      ),
      child: child,
    );
  }
}
