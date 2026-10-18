import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/di/injection.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  assert(
    _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty,
    'Missing Supabase config. Run with --dart-define-from-file=env/dev.json',
  );

  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  configureDependencies();

  await initializeDateFormatting('pt_PT');

  runApp(const App());
}
