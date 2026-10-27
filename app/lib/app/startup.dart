import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/session_bootstrap.dart';
import '../core/localization/localizations.dart';
import '../core/platform/document_language.dart';
import '../core/platform/first_page.dart';
import '../core/platform/push.dart';
import '../core/platform/session_storage.dart';
import '../core/widgets/state_message.dart';
import '../features/listings/data/models/first_page_model.dart';
import '../features/listings/presentation/cubit/listings_cubit.dart';
import '../features/listings/presentation/cubit/listings_state.dart';
import '../features/settings/data/supabase_language_repository.dart';
import '../features/settings/presentation/language_cubit.dart';
import 'app.dart';
import 'di/injection.dart';
import 'router/notification_taps.dart';
import 'theme/app_theme.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

/// How long the first start may wait for the network before saying so.
const _startTimeout = Duration(seconds: 20);

/// Draws a frame at once and then gets the app ready (Supabase, the
/// session, language). Android keeps its splash screen until the first frame,
/// so a start that waited for the network, or failed before `runApp`,
/// stayed on the splash forever; now it shows a spinner, and a failure
/// says what went wrong with a button to try again.
class Startup extends StatefulWidget {
  const Startup({super.key});

  @override
  State<Startup> createState() => _StartupState();
}

class _StartupState extends State<Startup> {
  /// Started once; a failure clears it so "Tentar novamente" starts it
  /// again, while one still waiting (a timeout) is waited for again.
  static Future<void>? _supabase;
  static var _dependenciesReady = false;

  AppLanguage _startupLanguage = AppLanguage.portuguese;
  late Future<void> _ready = _start();

  Future<void> _start() async {
    final preferences = await SharedPreferences.getInstance();
    _startupLanguage = SupabaseLanguageRepository.cachedIn(preferences, null);
    setDocumentLanguage(
      _startupLanguage.locale.toLanguageTag(),
      _startupLanguage.messages.appOpening,
    );
    if (_supabaseUrl.isEmpty || _supabasePublishableKey.isEmpty) {
      throw StateError(
        'Missing Supabase config: build with '
        '--dart-define-from-file=env/dev.json',
      );
    }
    await (_supabase ??= _initializeSupabase()).timeout(_startTimeout);
    if (!_dependenciesReady) {
      configureDependencies(preferences);
      _dependenciesReady = true;
    }
    // A cached choice is immediate; account preferences load independently
    // and never hold up browsing or the notification's deep link.
    getIt<LanguageCubit>();
    // The first listings while the session starts, not after it: without
    // a session the database answers as for an anonymous one (every
    // collected model), so a first visit doesn't wait for its sign-in;
    // a stored session goes with the request as usual. In the browser
    // index.html may already have asked (while the app downloaded).
    final listings = getIt<ListingsCubit>();
    if (listings.state.status == ListingsStatus.initial) {
      unawaited(listings.load(early: takeFirstPage().then(firstPageFromJson)));
    }
    // Browsing works without a session, so a slow sign-in doesn't hold
    // the app (it is tried again on the next start).
    await ensureSession(
      Supabase.instance.client,
    ).timeout(_startTimeout, onTimeout: () {});
    // The Android app: a tapped notification opens its page, once the
    // app's router is on screen.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(DevicePush.listenToTaps(openNotification)),
    );
  }

  static Future<void> _initializeSupabase() async {
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        publishableKey: _supabasePublishableKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: sessionStorage(_supabaseUrl),
        ),
      );
    } on Object {
      _supabase = null;
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return const App();
        }
        return _waiting(
          context,
          snapshot.hasError
              ? StateMessage(
                  icon: Icons.cloud_off,
                  title: _startupLanguage.messages.couldNotOpenApp,
                  message: _startupLanguage.messages
                      .startupConnectionError(
                        error: _describe(snapshot.error),
                      ),
                  actionLabel: _startupLanguage.messages.retry,
                  onAction: () => setState(() => _ready = _start()),
                )
              : const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  /// The screen before the app: only a theme and a Material, no
  /// MaterialApp. On the web a MaterialApp's navigator would report "/" to
  /// the browser, replacing the address a notification opened
  /// (`/#/deals/<id>`), and its Title would paint the primary colour into
  /// `theme-color` (the iPhone's status bar).
  static Widget _waiting(BuildContext context, Widget child) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final theme = dark ? AppTheme.dark : AppTheme.light;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: theme,
        child: Material(color: theme.scaffoldBackgroundColor, child: child),
      ),
    );
  }

  String _describe(Object? error) => switch (error) {
    TimeoutException() => _startupLanguage.messages.noResponseFromServer,
    final Object e => '$e',
    null => '',
  };
}
