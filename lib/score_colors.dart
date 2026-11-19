import 'package:flutter/material.dart';

import 'package:lucid/constants.dart';
import 'package:lucid/theme.dart';

// Score palette: soft red (0) -> warm amber (50) -> mint green (100).
const Color SCORE_COLOR_LOW = Color(0xFFE05D5D),
    SCORE_COLOR_MID = Color(0xFFF0B429),
    SCORE_COLOR_HIGH = Color(0xFF3FB27F);

const LinearGradient SCORE_GRADIENT = LinearGradient(
  colors: [SCORE_COLOR_LOW, SCORE_COLOR_MID, SCORE_COLOR_HIGH],
);

/// Color for a score between RATING_MIN and RATING_MAX (values outside are
/// clamped). Works for averages too, e.g. 72.5.
Color scoreColor(num score) {
  double t = ((score - RATING_MIN) / (RATING_MAX - RATING_MIN))
      .clamp(0.0, 1.0)
      .toDouble();
  if (t < 0.5) {
    return Color.lerp(SCORE_COLOR_LOW, SCORE_COLOR_MID, t * 2)!;
  }
  return Color.lerp(SCORE_COLOR_MID, SCORE_COLOR_HIGH, (t - 0.5) * 2)!;
}

/// Color for days and sessions that were not rated: a soft version of the
/// app's accent (the same everywhere: calendar, year overview, session list).
Color unratedColor(BuildContext context) {
  ThemeData theme = Theme.of(context);
  return Color.alphaBlend(
    theme.colorScheme.primary.withValues(alpha: 0.55),
    theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
  );
}

/// Text/icon color that stays readable on top of [background].
Color onColor(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black87;
}

/// Round badge showing a score in its color, or a grey dash when unrated.
class ScoreBadge extends StatelessWidget {
  const ScoreBadge({super.key, required this.score, this.size = 40.0});

  final num? score;
  final double size;

  @override
  Widget build(BuildContext context) {
    ColorScheme colors = Theme.of(context).colorScheme;
    num? value = score;
    Color background = value == null
        ? colors.surfaceContainerHighest
        : scoreColor(value);
    Color foreground = value == null
        ? colors.onSurfaceVariant
        : onColor(background);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: value == null
            ? lineBorder(context)
            : edgeBorder(context, background),
      ),
      child: Text(
        value == null ? "–" : "${value.round()}",
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}
