import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app/startup.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Pages opened with `push` (a listing, the pages from Mais) show their
  // own address, so a reload or a shared address opens them again.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(const Startup());
}
