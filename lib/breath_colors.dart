// Colors for the parts of a breath. The same four colors are used for the
// breathing wave, the program cards, the pills, the sliders and the
// meditation screen, so each part is easy to recognize everywhere.

import 'package:flutter/material.dart';

import 'package:lucid/breathing.dart';

const Color INHALE_COLOR =
        Color(0xFF6FB59A), // sage green
    HOLD_IN_COLOR =
        Color(0xFFE2B865), // warm sand
    EXHALE_COLOR =
        Color(0xFF5B8FC9), // sky blue
    HOLD_OUT_COLOR = Color(0xFFA394D6); // lavender

Color phaseColor(BreathPhase phase) => switch (phase) {
  BreathPhase.inhale || BreathPhase.inhaleLast => INHALE_COLOR,
  BreathPhase.inhaleHold => HOLD_IN_COLOR,
  BreathPhase.exhale || BreathPhase.exhaleLast => EXHALE_COLOR,
  BreathPhase.exhaleHold => HOLD_OUT_COLOR,
};

/// Readable text on a light tint of [color]: a deeper shade of it (a lighter
/// one in dark mode).
Color tintTextColor(BuildContext context, Color color) =>
    Theme.of(context).brightness == Brightness.dark
    ? Color.lerp(color, Colors.white, 0.35)!
    : Color.lerp(color, Colors.black, 0.5)!;

/// A soft background tint of [color] over the card color.
Color tintColor(BuildContext context, Color color, [double amount = 0.18]) {
  ThemeData theme = Theme.of(context);
  return Color.alphaBlend(
    color.withValues(alpha: amount),
    theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
  );
}

/// Seconds for display: "4", "1.5".
String secondsText(int ms) {
  double s = ms / Duration.millisecondsPerSecond;
  return s == s.roundToDouble() ? "${s.round()}" : s.toStringAsFixed(1);
}
