import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/localization/localizations.dart';
import '../core/platform/document_language.dart';
import '../core/platform/home_screen_app.dart';
import '../features/settings/presentation/language_cubit.dart';
import 'di/injection.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

const _title = 'Motorcycle Deal Tracker';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LanguageCubit, LanguageState>(
      bloc: getIt<LanguageCubit>(),
      builder: (context, state) {
        setDocumentLanguage(
          state.language.locale.toLanguageTag(),
          state.language.messages.appOpening,
        );
        return MaterialApp.router(
          locale: state.language.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: appLocales,
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
      },
    );
  }

  /// On iPhone/iPad, the bottom safe area Flutter on the web doesn't
  /// report ([iosBottomInset]), so the tab bar (and every SafeArea at the
  /// bottom) stays clear of the home bar or of Safari's tint strip.
  static Widget _withHomeBarInset(BuildContext context, Widget child) {
    final inset = iosBottomInset;
    final media = MediaQuery.of(context);
    if (inset == 0 || media.viewPadding.bottom >= inset) return child;
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(bottom: inset),
        viewPadding: media.viewPadding.copyWith(bottom: inset),
      ),
      child: child,
    );
  }
}
