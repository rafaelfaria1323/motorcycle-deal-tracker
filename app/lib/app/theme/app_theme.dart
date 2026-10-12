import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFFE4572E);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
  );
}
