import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/di/injection.dart';
import 'core/auth/session_bootstrap.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  assert(
    _supabaseUrl.isNotEmpty && _supabasePublishableKey.isNotEmpty,
    'Missing Supabase config. Run with --dart-define-from-file=env/dev.json',
  );

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );
  await ensureSession(Supabase.instance.client);
  configureDependencies();

  await initializeDateFormatting('pt_PT');

  runApp(const App());
}
