import 'package:flutter/material.dart';

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
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
