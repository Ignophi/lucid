// The breathing guide's timing, worked out from the time since the session
// started (never by counting timer ticks), so it stays right even if the
// phone was busy, the screen was off or another app was open. Plain Dart so
// it can be unit tested (see test/breathing_test.dart).

import 'dart:math' as math;

/// The parts of one breath, in order. "Last" is an optional second inhale
/// (or exhale) after the hold, as in the physiological sigh.
enum BreathPhase {
  inhale,
  inhaleHold,
  inhaleLast,
  exhale,
  exhaleHold,
  exhaleLast,
}

/// One breath: how long each part lasts, in milliseconds.
class BreathPattern {
  BreathPattern(List<int> inhale, List<int> exhale)
    : _lengths = [
        for (int i = 0; i < 3; i++) i < inhale.length ? inhale[i] : 0,
        for (int i = 0; i < 3; i++) i < exhale.length ? exhale[i] : 0,
      ].map((ms) => ms < 0 ? 0 : ms).toList();

  // inhale, inhale hold, inhale last, exhale, exhale hold, exhale last
  final List<int> _lengths;

  /// How long each part lasts, in the order of [BreathPhase].
  List<int> get lengths => List.unmodifiable(_lengths);

  int lengthOf(BreathPhase phase) => _lengths[phase.index];

  int get inhaling => _lengths[0] + _lengths[2];
  int get exhaling => _lengths[3] + _lengths[5];
  int get inhaleTotal => _lengths[0] + _lengths[1] + _lengths[2];

  /// Length of one breath in milliseconds (0 if no pattern is set).
  int get breath => _lengths.fold(0, (total, ms) => total + ms);

  /// Breaths per minute the guide sets (null without a pattern).
  double? get breathsPerMinute => breath > 0 ? 60000 / breath : null;

  /// The part of the breath at [ms] into it, and when that part started.
  (BreathPhase, int) phaseAt(int ms) {
    int start = 0;
    for (int i = 0; i < _lengths.length; i++) {
      int end = start + _lengths[i];
      if (ms < end) return (BreathPhase.values[i], start);
      start = end;
    }
    return (BreathPhase.exhaleLast, start);
  }

  /// Size of the breathing circle (0 empty, 1 full) at [ms] into a breath:
  /// it grows while inhaling, stays during holds, shrinks while exhaling.
  double scaleAt(int ms) {
    int t = ms.clamp(0, breath);
    int inhale = _lengths[0], hold = _lengths[1];
    if (t < inhaleTotal) {
      if (inhaling <= 0) return 1.0;
      int inhaled = t < inhale
          ? t
          : t < inhale + hold
          ? inhale
          : inhale + (t - inhale - hold);
      return (inhaled / inhaling).clamp(0.0, 1.0);
    }
    t -= inhaleTotal;
    int exhale = _lengths[3], exhaleHold = _lengths[4];
    if (exhaling <= 0) return 0.0;
    int exhaled = t < exhale
        ? t
        : t < exhale + exhaleHold
        ? exhale
        : exhale + (t - exhale - exhaleHold);
    return (1 - exhaled / exhaling).clamp(0.0, 1.0);
  }

  /// Like [scaleAt], but each part starts and ends gently (as breathing
  /// does), for drawing the circle and the breathing wave.
  double easedScaleAt(int ms) {
    int t = ms.clamp(0, breath);
    int start = 0;
    for (int length in _lengths) {
      int end = start + length;
      if (length > 0 && t < end) {
        double from = scaleAt(start), to = scaleAt(end);
        double f = (t - start) / length;
        return from + (to - from) * (0.5 - 0.5 * math.cos(math.pi * f));
      }
      start = end;
    }
    return scaleAt(t);
  }
}

/// Where a session is at a given moment.
class BreathingState {
  const BreathingState({
    required this.breath,
    required this.phase,
    required this.intoPhase,
    required this.phaseLeft,
    required this.cycleProgress,
    required this.scale,
    required this.remaining,
    required this.breaths,
    required this.finished,
  });

  /// Index of the current breath (0 for the first).
  final int breath;
  final BreathPhase phase;

  /// Time since the current part of the breath started, and time left in it.
  final Duration intoPhase, phaseLeft;

  /// How far through the current breath (0 at the start, towards 1).
  final double cycleProgress;

  /// Size of the breathing circle (0 empty, 1 full), eased.
  final double scale;

  /// Time left of the set duration (zero while the last breath finishes).
  final Duration remaining;

  /// Breaths completed so far.
  final int breaths;

  /// True once the set time is up and the last breath is complete.
  final bool finished;
}

/// A session of [duration] with the breathing [pattern]. It ends at the end
/// of the first breath that finishes after the duration is up.
class BreathingSession {
  BreathingSession({required this.pattern, required this.duration});

  final BreathPattern pattern;
  final Duration duration;

  /// When the session ends, from its start.
  Duration get length {
    int ms = duration.inMilliseconds, breath = pattern.breath;
    if (ms <= 0) return Duration.zero;
    if (breath <= 0) return duration;
    return Duration(milliseconds: ((ms + breath - 1) ~/ breath) * breath);
  }

  BreathingState stateAt(Duration elapsed) {
    int ms = elapsed.inMilliseconds < 0 ? 0 : elapsed.inMilliseconds;
    int end = length.inMilliseconds, breath = pattern.breath;
    bool finished = ms >= end;
    if (finished) ms = end;
    int index = breath > 0 ? ms ~/ breath : 0;
    int inBreath = breath > 0 ? ms % breath : 0;
    Duration remaining = duration - Duration(milliseconds: ms);
    if (remaining.isNegative) remaining = Duration.zero;
    var (phase, phaseStart) = breath > 0
        ? pattern.phaseAt(inBreath)
        : (BreathPhase.inhale, 0);
    return BreathingState(
      breath: index,
      phase: phase,
      intoPhase: Duration(milliseconds: inBreath - phaseStart),
      phaseLeft: Duration(
        milliseconds: breath > 0
            ? phaseStart + pattern.lengthOf(phase) - inBreath
            : 0,
      ),
      cycleProgress: breath > 0 ? inBreath / breath : 0.0,
      scale: breath > 0 ? pattern.easedScaleAt(inBreath) : 0.0,
      remaining: remaining,
      breaths: index,
      finished: finished,
    );
  }
}
