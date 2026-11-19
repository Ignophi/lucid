import 'package:flutter/material.dart';

/// Width of the thin outline around cards and stat boxes.
const double OUTLINE_WIDTH = 0.6;

/// Width of the even thinner edge around colored shapes (bars, day squares,
/// bubbles, badges...), so each one stands out crisply.
const double EDGE_WIDTH = 0.5;

/// Edge color for a shape filled with [fill]: a deeper shade of the same
/// color in light mode, a lighter one in dark mode (so it shows against the
/// dark background). Opaque, even when the fill is see-through.
Color edgeColorFor(Color fill, Brightness brightness) {
  Color base = fill.withValues(alpha: 1.0);
  return brightness == Brightness.dark
      ? Color.lerp(base, const Color(0xFFFFFFFF), 0.45)!
      : Color.lerp(base, const Color(0xFF000000), 0.3)!;
}

Color edgeColor(BuildContext context, Color fill) =>
    edgeColorFor(fill, Theme.of(context).brightness);

/// The thin edge for a shape filled with [fill].
Border edgeBorder(BuildContext context, Color fill) =>
    Border.all(color: edgeColor(context, fill), width: EDGE_WIDTH);

/// Neutral color for outlines and thin lines (cards, axes, empty days,
/// pills). In dark mode it is lighter, so the lines stay visible.
Color lineColorFor(ColorScheme colors) => colors.brightness == Brightness.dark
    ? Color.lerp(colors.outlineVariant, colors.outline, 0.55)!
    : colors.outlineVariant;

Color lineColor(BuildContext context) =>
    lineColorFor(Theme.of(context).colorScheme);

/// The thin neutral edge, for grey shapes (empty days, pills, tracks).
Border lineBorder(BuildContext context) =>
    Border.all(color: lineColor(context), width: EDGE_WIDTH);

/// The app's accent: a calm, serene blue that sits between the indigo and
/// teal of the Lucid logo. Other calm options: Color(0xFF3D7F95) (teal),
/// Color(0xFF5B6FB5) (dusk indigo).
const Color APP_ACCENT = Color(0xFF4A7AB0);

/// The app's look (Material 3): a soft palette generated from [seedColor],
/// rounded cards with a thin outline, round buttons and flat surfaces.
///
/// [backgroundColor] is only set when the user picked a custom background.
ThemeData buildTheme(
  Color seedColor,
  Brightness brightness, {
  Color? backgroundColor,
}) {
  ColorScheme colors = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  Color background = backgroundColor ?? colors.surface;
  const BorderRadius cardRadius = BorderRadius.all(Radius.circular(20.0));
  const BorderRadius fieldRadius = BorderRadius.all(Radius.circular(14.0));
  const BorderRadius menuRadius = BorderRadius.all(Radius.circular(14.0));
  BorderSide outline = BorderSide(
    color: lineColorFor(colors),
    width: OUTLINE_WIDTH,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    // Parts of the app read primaryColor directly. Keep it on the accent
    // (in dark mode Material 3 would otherwise make it a dark grey).
    primaryColor: colors.primary,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    appBarTheme: AppBarThemeData(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0.0,
      titleTextStyle: TextStyle(
        fontSize: 22.0,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0.0,
      color: colors.surfaceContainerLow,
      // Thin outline so cards stand out from the background
      shape: RoundedRectangleBorder(borderRadius: cardRadius, side: outline),
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: cardRadius),
    ),
    navigationDrawerTheme: const NavigationDrawerThemeData(
      surfaceTintColor: Colors.transparent,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.primaryContainer,
      foregroundColor: colors.onPrimaryContainer,
      elevation: 1.0,
      highlightElevation: 2.0,
      shape: StadiumBorder(
        side: BorderSide(
          color: edgeColorFor(colors.primaryContainer, brightness),
          width: EDGE_WIDTH,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.6),
      border: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: outline,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: outline,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: colors.primary, width: 2.0),
      ),
    ),
    // Newer, rounder slider design (Flutter will make this the default)
    // ignore: deprecated_member_use
    sliderTheme: const SliderThemeData(year2023: false),
    dividerTheme: DividerThemeData(
      thickness: OUTLINE_WIDTH,
      space: 24.0,
      color: lineColorFor(colors),
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(borderRadius: menuRadius, side: outline),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: menuRadius, side: outline),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: cardRadius, side: outline),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(
          BorderSide(color: colors.outline, width: OUTLINE_WIDTH),
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: menuRadius),
    ),
  );
}
