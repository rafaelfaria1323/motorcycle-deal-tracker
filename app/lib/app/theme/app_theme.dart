import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// The app's look: cool greys with one racing-orange accent, white cards
/// with a hairline border, Barlow for text and Barlow Semi Condensed for
/// titles, prices and scores.
abstract final class AppTheme {
  static const bodyFont = 'Barlow';
  static const displayFont = 'BarlowSemiCondensed';

  /// Page background in light and dark mode. Also the browser/iPhone status
  /// bar colour: keep `web/index.html` and `web/manifest.json` in step.
  static const lightBackground = Color(0xFFF4F5F7);
  static const darkBackground = Color(0xFF0F1115);

  /// How error messages and invalid-field hints look.
  static TextStyle errorText(BuildContext context) =>
      TextStyle(color: Theme.of(context).colorScheme.error);

  /// Prices and scores: every digit the same width, so figures line up.
  static const tabularFigures = [FontFeature.tabularFigures()];

  /// Small grey figures beside a chart or a price strip.
  static TextStyle figureLabel(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: tabularFigures,
    );
  }

  /// The small capitals line above a title (a page's eyebrow, the listing's
  /// site): bold and spaced, in the accent colour.
  static TextStyle? eyebrow(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
      color: theme.colorScheme.primary,
    );
  }

  /// A heading in capitals over a group of rows (a day of alerts, a kind
  /// of account).
  static TextStyle? groupLabel(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 1.2,
    );
  }

  /// Small text on a dark pill over a photo (the card's place, the
  /// badge's "Deal Score").
  static const onPhotoLabel = TextStyle(
    fontFamily: bodyFont,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.onPhoto,
  );

  static ThemeData get light => _build(_lightScheme, AppColors.light);

  static ThemeData get dark => _build(_darkScheme, AppColors.dark);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFC5420F),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFFFE4D8),
    onPrimaryContainer: Color(0xFF5C1A00),
    secondary: Color(0xFF242B35),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE4E8EE),
    onSecondaryContainer: Color(0xFF1B2129),
    tertiary: Color(0xFF0A7F57),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFD5F5E7),
    onTertiaryContainer: Color(0xFF003D27),
    error: Color(0xFFD12B2B),
    onError: Colors.white,
    errorContainer: Color(0xFFFDE4E4),
    onErrorContainer: Color(0xFF7A1111),
    surface: lightBackground,
    onSurface: Color(0xFF14181E),
    onSurfaceVariant: Color(0xFF5A626D),
    surfaceDim: Color(0xFFDDE0E5),
    surfaceBright: Colors.white,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF9FAFB),
    surfaceContainer: Color(0xFFEDEFF2),
    surfaceContainerHigh: Color(0xFFE7E9ED),
    surfaceContainerHighest: Color(0xFFDFE2E7),
    outline: Color(0xFFB9BFC8),
    outlineVariant: Color(0xFFE1E4E9),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFF242B35),
    onInverseSurface: Color(0xFFF1F3F5),
    inversePrimary: Color(0xFFFF9B6E),
    surfaceTint: Colors.transparent,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFF6B2E),
    onPrimary: Color(0xFF1F0A00),
    primaryContainer: Color(0xFF41200F),
    onPrimaryContainer: Color(0xFFFFC2A6),
    secondary: Color(0xFFC9D1DC),
    onSecondary: Color(0xFF12161B),
    secondaryContainer: Color(0xFF272D36),
    onSecondaryContainer: Color(0xFFDDE3EA),
    tertiary: Color(0xFF3DD68C),
    onTertiary: Color(0xFF00281A),
    tertiaryContainer: Color(0xFF0F3A2A),
    onTertiaryContainer: Color(0xFFB4F2D3),
    error: Color(0xFFFF7A7A),
    onError: Color(0xFF3A0000),
    errorContainer: Color(0xFF3D1517),
    onErrorContainer: Color(0xFFFFC9C9),
    surface: darkBackground,
    onSurface: Color(0xFFECEEF1),
    onSurfaceVariant: Color(0xFF9AA3AE),
    surfaceDim: darkBackground,
    surfaceBright: Color(0xFF2C323B),
    surfaceContainerLowest: Color(0xFF171A20),
    surfaceContainerLow: Color(0xFF14171C),
    surfaceContainer: Color(0xFF1C2027),
    surfaceContainerHigh: Color(0xFF232830),
    surfaceContainerHighest: Color(0xFF2B313A),
    outline: Color(0xFF4A525D),
    outlineVariant: Color(0xFF272C34),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFECEEF1),
    onInverseSurface: Color(0xFF14181E),
    inversePrimary: Color(0xFFB73D0E),
    surfaceTint: Colors.transparent,
  );

  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    TextStyle? display(TextStyle? style, FontWeight weight) => style?.copyWith(
      fontFamily: displayFont,
      fontWeight: weight,
      letterSpacing: 0,
    );

    return base
        .copyWith(
          displayLarge: display(base.displayLarge, FontWeight.w700),
          displayMedium: display(base.displayMedium, FontWeight.w700),
          displaySmall: display(base.displaySmall, FontWeight.w700),
          headlineLarge: display(base.headlineLarge, FontWeight.w700),
          headlineMedium: display(base.headlineMedium, FontWeight.w700),
          headlineSmall: display(base.headlineSmall, FontWeight.w700),
          titleLarge: display(base.titleLarge, FontWeight.w700),
          titleMedium: base.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
          titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          bodyLarge: base.bodyLarge?.copyWith(fontSize: 17),
          bodyMedium: base.bodyMedium?.copyWith(fontSize: 15),
          bodySmall: base.bodySmall?.copyWith(fontSize: 13),
          labelLarge: base.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }

  static ThemeData _build(ColorScheme scheme, AppColors colors) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: bodyFont,
    );
    final text = _textTheme(base.textTheme, scheme);
    const radius = 14.0;
    const controlRadius = BorderRadius.all(Radius.circular(10));
    final hairline = BorderSide(color: scheme.outlineVariant);

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      extensions: [colors],
      // The app bar keeps the page's background when content scrolls under
      // it, so it stays the same colour as the status bar above it.
      appBarTheme: AppBarTheme(
        // Every app bar reports a status bar colour, and on the web Flutter
        // writes it into the page's theme-color, which Safari paints the
        // status bar with. Material 3's default is transparent black, which
        // Safari shows as black even in light mode; the page background is
        // what the status bar must show.
        systemOverlayStyle:
            (scheme.brightness == Brightness.dark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark)
                .copyWith(statusBarColor: scheme.surface),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 20,
        toolbarHeight: 68,
        titleTextStyle: text.headlineSmall?.copyWith(fontSize: 24),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: hairline,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: controlRadius,
        ),
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: controlRadius,
        ),
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: text.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: text.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: text.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: controlRadius),
        extendedTextStyle: text.labelLarge?.copyWith(fontSize: 16),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        selectedColor: scheme.primaryContainer,
        side: hairline,
        shape: const RoundedRectangleBorder(borderRadius: controlRadius),
        labelStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 18),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: text.headlineSmall,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: controlRadius,
          side: hairline,
        ),
        textStyle: text.bodyLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: const RoundedRectangleBorder(borderRadius: controlRadius),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: const RoundedRectangleBorder(borderRadius: controlRadius),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: text.labelLarge,
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
    );
  }
}
