// The breathing wave: one breath drawn as a smooth curve that rises while
// inhaling, stays up while holding and falls while exhaling, each part in
// its own color, with the seconds at each change underneath. On the
// meditation screen a dot moves along it to show where you are.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:lucid/breath_colors.dart';
import 'package:lucid/breathing.dart';
import 'package:lucid/theme.dart';

class BreathWave extends StatelessWidget {
  const BreathWave({
    super.key,
    required this.pattern,
    this.progress,
    this.height = 80.0,
    this.showTicks = true,
    this.strokeWidth = 2.2,
  });

  final BreathPattern pattern;

  /// Where in the breath you are (0 to 1); null for a still picture.
  final ValueListenable<double>? progress;
  final double height, strokeWidth;
  final bool showTicks;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WavePainter(
          lengths: pattern.lengths,
          pattern: pattern,
          progress: progress,
          showTicks: showTicks,
          strokeWidth: strokeWidth,
          lineColor: lineColor(context),
          labelStyle:
              (theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11))
                  .copyWith(color: theme.colorScheme.onSurfaceVariant),
          brightness: theme.brightness,
          dotCenter: theme.colorScheme.surface,
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.lengths,
    required this.pattern,
    required this.progress,
    required this.showTicks,
    required this.strokeWidth,
    required this.lineColor,
    required this.labelStyle,
    required this.brightness,
    required this.dotCenter,
  }) : super(repaint: progress);

  final List<int> lengths;
  final BreathPattern pattern;
  final ValueListenable<double>? progress;
  final bool showTicks;
  final double strokeWidth;
  final Color lineColor, dotCenter;
  final TextStyle labelStyle;
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    int breath = pattern.breath;
    if (breath <= 0 || size.width <= 0) return;
    double labelHeight = showTicks ? 16.0 : 0.0;
    double radius = progress != null ? 7.0 : strokeWidth;
    Rect plot = Rect.fromLTRB(
      radius,
      radius + 1.0,
      size.width - radius,
      size.height - labelHeight - strokeWidth,
    );
    double xOf(int ms) => plot.left + plot.width * ms / breath;
    double yOf(double v) => plot.bottom - plot.height * v;

    // Baseline
    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      Paint()
        ..color = lineColor
        ..strokeWidth = EDGE_WIDTH * 2,
    );

    double? at = progress?.value.clamp(0.0, 1.0);
    double cut = at == null ? plot.right : plot.left + plot.width * at;

    // Each part: the area under the curve and the curve itself
    int start = 0;
    List<int> boundaries = [0];
    for (int i = 0; i < lengths.length; i++) {
      int length = lengths[i];
      if (length <= 0) continue;
      int end = start + length;
      Color color = phaseColor(BreathPhase.values[i]);
      int steps = math.max(8, (xOf(end) - xOf(start)) ~/ 2);
      Path curve = Path();
      for (int k = 0; k <= steps; k++) {
        int t = start + (length * k / steps).round();
        Offset point = Offset(xOf(t), yOf(pattern.easedScaleAt(t)));
        k == 0
            ? curve.moveTo(point.dx, point.dy)
            : curve.lineTo(point.dx, point.dy);
      }
      // The area under the curve; a hold after exhaling (flat at the
      // bottom) is shown as a light band instead, so it can be seen
      bool lowHold = BreathPhase.values[i] == BreathPhase.exhaleHold;
      Path area = lowHold
          ? (Path()..addRect(
              Rect.fromLTRB(xOf(start), plot.top, xOf(end), plot.bottom),
            ))
          : (Path.from(curve)
              ..lineTo(xOf(end), plot.bottom)
              ..lineTo(xOf(start), plot.bottom)
              ..close());
      Paint stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      double fillAlpha =
          (brightness == Brightness.dark ? 0.32 : 0.26) * (lowHold ? 0.6 : 1);

      // Still picture: everything in full color. With progress, the part of
      // the breath still to come is faded.
      if (at == null) {
        canvas.drawPath(
          area,
          Paint()..color = color.withValues(alpha: fillAlpha),
        );
        canvas.drawPath(curve, stroke);
      } else {
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(cut, 0, size.width, size.height));
        canvas.drawPath(
          area,
          Paint()..color = color.withValues(alpha: fillAlpha * 0.45),
        );
        canvas.drawPath(curve, stroke..color = color.withValues(alpha: 0.4));
        canvas.restore();
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(0, 0, cut, size.height));
        canvas.drawPath(
          area,
          Paint()..color = color.withValues(alpha: fillAlpha),
        );
        canvas.drawPath(curve, stroke..color = color);
        canvas.restore();
      }
      start = end;
      boundaries.add(end);
    }

    // Thin lines where one part changes to the next
    Paint divider = Paint()
      ..color = lineColor.withValues(alpha: 0.6)
      ..strokeWidth = EDGE_WIDTH;
    for (int b in boundaries.skip(1).take(boundaries.length - 2)) {
      canvas.drawLine(
        Offset(xOf(b), plot.top),
        Offset(xOf(b), plot.bottom),
        divider,
      );
    }

    // Seconds under each change (skipping labels that would overlap; the
    // last one always shows)
    if (showTicks) {
      double lastRight = -double.infinity;
      for (int j = 0; j < boundaries.length; j++) {
        int b = boundaries[j];
        TextPainter label = TextPainter(
          text: TextSpan(text: secondsText(b), style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        double x = (xOf(b) - label.width / 2).clamp(
          0.0,
          size.width - label.width,
        );
        bool last = j == boundaries.length - 1;
        if (x < lastRight + 4.0 && !last) continue;
        label.paint(canvas, Offset(x, plot.bottom + 3.0));
        lastRight = x + label.width;
      }
    }

    // The dot: where you are now
    if (at != null) {
      int t = (breath * at).round();
      Offset dot = Offset(cut, yOf(pattern.easedScaleAt(t)));
      Color color = phaseColor(pattern.phaseAt(math.min(t, breath - 1)).$1);
      canvas.drawCircle(
        dot,
        radius + 3.0,
        Paint()..color = color.withValues(alpha: 0.25),
      );
      canvas.drawCircle(dot, radius, Paint()..color = color);
      canvas.drawCircle(
        dot,
        radius,
        Paint()
          ..color = edgeColorFor(color, brightness)
          ..style = PaintingStyle.stroke
          ..strokeWidth = EDGE_WIDTH * 2,
      );
      canvas.drawCircle(dot, radius * 0.38, Paint()..color = dotCenter);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      !listEquals(old.lengths, lengths) ||
      old.progress != progress ||
      old.lineColor != lineColor ||
      old.brightness != brightness ||
      old.showTicks != showTicks;
}
