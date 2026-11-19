// Turns what the phone's sensors picked up during a session into numbers:
// stillness, position (flat / upright / walking), steps, estimated breaths,
// environment loudness and interruptions. Plain Dart (no Flutter) so it can
// be unit tested with simulated signals (see test/session_measure_test.dart).
//
// Measurements are estimates. The app's own guidance (vibrations, tones,
// spoken cues) is cut out first, so it isn't mistaken for movement, noise or
// breathing.

import 'dart:math' as math;

import 'package:lucid/constants.dart';

/// One accelerometer reading (m/s², gravity included), [t] seconds into the
/// session.
class MotionSample {
  const MotionSample(this.t, this.x, this.y, this.z);
  final double t, x, y, z;
}

/// A stretch of time when the app itself vibrated or made a sound.
class GuidanceMark {
  const GuidanceMark(
    this.start,
    this.end, {
    this.sound = false,
    this.vibration = false,
  });
  final double start, end;
  final bool sound, vibration;
}

/// Keys of the measurements map stored with a session (Session.measurements).
class Measure {
  Measure._();
  static const String version = "v", seconds = "seconds", stillness = "stillness", // 0-100: share of time the phone was still
  movements = "movements", // separate bouts of movement
  flat = "flat", // share of time still with the phone flat (lying down)
  upright = "upright", // share of time still, phone tilted (in hand)
  walking = "walking", // share of time walking
  steps = "steps", cadence = "cadence", // steps per minute while walking
  paceSteady = "paceSteady", // 0-100: how even the steps were
  breaths = "breaths", // estimated number of breaths
  breathRate = "breathRate", // breaths per minute
  breathSource = "breathSource", // "motion" or "sound"
  breathConfidence = "breathConfidence", // 0-100
  breathSteady = "breathSteady", // 0-100: how regular the breathing was
  noiseDb = "noiseDb", // typical loudness, dBFS (relative to the mic)
  peakDb = "peakDb", // loud end (95th percentile), dBFS
  quiet = "quiet", // 0-100
  loudMoments = "loudMoments", interruptions = "interruptions", // times the app was left
  awaySeconds = "awaySeconds", // total time away from the app
  guideRate = "guideRate"; // breaths per minute the guide set

  static const String sourceMotion = "motion", sourceSound = "sound";
}

// --- small signal helpers --------------------------------------------------

/// Centered moving average over [window] samples (prefix sums).
List<double> movingAverage(List<double> values, int window) {
  int n = values.length;
  if (n == 0 || window <= 1) return List.of(values);
  List<double> sums = List.filled(n + 1, 0.0);
  for (int i = 0; i < n; i++) {
    sums[i + 1] = sums[i] + values[i];
  }
  int half = window ~/ 2;
  return [
    for (int i = 0; i < n; i++)
      () {
        int a = math.max(0, i - half), b = math.min(n, i + half + 1);
        return (sums[b] - sums[a]) / (b - a);
      }(),
  ];
}

double _mean(Iterable<double> values) {
  double total = 0;
  int count = 0;
  for (double v in values) {
    total += v;
    count++;
  }
  return count == 0 ? 0 : total / count;
}

double _std(List<double> values) {
  if (values.length < 2) return 0;
  double m = _mean(values);
  double total = 0;
  for (double v in values) {
    total += (v - m) * (v - m);
  }
  return math.sqrt(total / values.length);
}

double percentile(List<double> values, double p) {
  if (values.isEmpty) return double.nan;
  List<double> sorted = List.of(values)..sort();
  double index = (sorted.length - 1) * p;
  int low = index.floor(), high = index.ceil();
  return sorted[low] + (sorted[high] - sorted[low]) * (index - low);
}

/// Resamples (t, value) points to [rate] Hz by holding the latest value.
List<double> _resample(List<double> t, List<double> v, double rate) {
  if (t.isEmpty) return [];
  int n = ((t.last - t.first) * rate).floor() + 1;
  List<double> out = List.filled(n, 0.0);
  int j = 0;
  for (int i = 0; i < n; i++) {
    double time = t.first + i / rate;
    while (j + 1 < t.length && t[j + 1] <= time) {
      j++;
    }
    out[i] = v[j];
  }
  return out;
}

/// Strongest repeating period in [signal] (sampled at [rate] Hz) between
/// [minPeriod] and [maxPeriod] seconds, from its autocorrelation. Returns
/// (period in seconds, strength 0-1) or null.
(double, double)? dominantPeriod(
  List<double> signal,
  double rate, {
  double minPeriod = 1.5,
  double maxPeriod = 24.0,
}) {
  int n = signal.length;
  int minLag = math.max(1, (minPeriod * rate).round());
  int maxLag = math.min(n ~/ 2, (maxPeriod * rate).round());
  if (maxLag <= minLag + 2) return null;
  double m = _mean(signal);
  List<double> x = [for (double v in signal) v - m];
  double energy = 0;
  for (double v in x) {
    energy += v * v;
  }
  if (energy <= 1e-12) return null;
  List<double> r = List.filled(maxLag + 1, 0.0);
  for (int lag = minLag - 1; lag <= maxLag; lag++) {
    if (lag < 1) continue;
    double total = 0;
    for (int i = 0; i + lag < n; i++) {
      total += x[i] * x[i + lag];
    }
    // Normalize for the shrinking overlap
    r[lag] = total / energy * n / (n - lag);
  }
  // First clear peak: a local maximum close to the highest one (avoids
  // picking a multiple of the true period)
  double best = 0;
  for (int lag = minLag; lag < maxLag; lag++) {
    best = math.max(best, r[lag]);
  }
  if (best <= 0) return null;
  for (int lag = minLag; lag < maxLag; lag++) {
    if (r[lag] >= r[lag - 1] && r[lag] >= r[lag + 1] && r[lag] >= 0.85 * best) {
      return (lag / rate, r[lag].clamp(0.0, 1.0));
    }
  }
  return null;
}

/// Indexes of peaks at least [minDistance] samples apart and above
/// [threshold].
List<int> findPeaks(List<double> signal, int minDistance, double threshold) {
  List<int> peaks = [];
  for (int i = 1; i < signal.length - 1; i++) {
    if (signal[i] < threshold) continue;
    if (signal[i] < signal[i - 1] || signal[i] < signal[i + 1]) continue;
    if (peaks.isNotEmpty && i - peaks.last < minDistance) {
      if (signal[i] > signal[peaks.last]) peaks[peaks.length - 1] = i;
      continue;
    }
    peaks.add(i);
  }
  return peaks;
}

/// 0-100 evenness of the gaps between [times] (100 = perfectly even).
int? _evenness(List<double> times) {
  if (times.length < 4) return null;
  List<double> gaps = [
    for (int i = 1; i < times.length; i++) times[i] - times[i - 1],
  ];
  double m = _mean(gaps);
  if (m <= 0) return null;
  double cv = _std(gaps) / m;
  return (100 * (1 - cv / 0.5)).round().clamp(0, 100);
}

/// Time ranges (merged and sorted) for quick "is t inside?" checks while
/// walking forward through a signal.
class _Ranges {
  _Ranges(Iterable<(double, double)> ranges) {
    List<(double, double)> sorted = List.of(ranges)
      ..sort((a, b) => a.$1.compareTo(b.$1));
    for (var (start, end) in sorted) {
      if (_list.isNotEmpty && start <= _list.last.$2) {
        _list[_list.length - 1] = (_list.last.$1, math.max(_list.last.$2, end));
      } else {
        _list.add((start, end));
      }
    }
  }

  factory _Ranges.of(
    List<GuidanceMark> marks,
    bool Function(GuidanceMark) kind,
  ) => _Ranges([
    for (GuidanceMark m in marks)
      if (kind(m)) (m.start, m.end),
  ]);

  final List<(double, double)> _list = [];
  int _index = 0;

  bool get isEmpty => _list.isEmpty;

  bool contains(double t) {
    if (_list.isEmpty) return false;
    if (_index > 0 && t < _list[_index - 1].$2) _index = 0; // went back
    while (_index < _list.length && _list[_index].$2 < t) {
      _index++;
    }
    return _index < _list.length && t >= _list[_index].$1;
  }
}

// --- motion ----------------------------------------------------------------

const double MOTION_RATE =
        25.0, // Hz, after resampling
    BREATH_RATE =
        10.0, // Hz, for breathing analysis
    STILL_LIMIT =
        0.2, // m/s² of movement below which the phone is "still"
    MOVE_LIMIT =
        0.6, // m/s² above which it counts as a movement
    WALK_LIMIT =
        0.9, // m/s² of sustained movement typical of walking
    FLAT_ANGLE = 30.0; // degrees from horizontal

Map<String, Object> _analyzeMotion(
  List<MotionSample> samples,
  List<GuidanceMark> marks,
) {
  if (samples.length < MOTION_RATE * 20) return {}; // under ~20 s of data
  // Cut out the app's own vibrations (hold the last reading instead)
  _Ranges vibrations = _Ranges.of(marks, (m) => m.vibration);
  List<double> t = [], xs = [], ys = [], zs = [];
  MotionSample? last;
  for (MotionSample s in samples) {
    bool buzzing = vibrations.contains(s.t);
    if (buzzing && last == null) continue; // nothing clean to hold yet
    MotionSample use = buzzing ? last! : s;
    if (!buzzing) last = s;
    t.add(s.t);
    xs.add(use.x);
    ys.add(use.y);
    zs.add(use.z);
  }
  double rate = MOTION_RATE;
  List<double> x = _resample(t, xs, rate),
      y = _resample(t, ys, rate),
      z = _resample(t, zs, rate);
  int n = x.length;
  int second = rate.round();

  // Gravity (1 s average) and movement on top of it
  List<double> gx = movingAverage(x, second),
      gy = movingAverage(y, second),
      gz = movingAverage(z, second);
  List<double> movement = [
    for (int i = 0; i < n; i++)
      math.sqrt(
        math.pow(x[i] - gx[i], 2) +
            math.pow(y[i] - gy[i], 2) +
            math.pow(z[i] - gz[i], 2),
      ),
  ];

  // Steps: peaks in the movement signal at a walking rhythm
  List<double> magnitude = [
    for (int i = 0; i < n; i++)
      math.sqrt(x[i] * x[i] + y[i] * y[i] + z[i] * z[i]),
  ];
  List<double> stepSignal = [
    for (double v in movingAverage(magnitude, (rate * 0.12).round())) v,
  ];
  List<double> baseline = movingAverage(magnitude, second);
  for (int i = 0; i < n; i++) {
    stepSignal[i] -= baseline[i];
  }

  // Classify each second
  int seconds = n ~/ second;
  int still = 0, flat = 0, walk = 0;
  List<bool> moving = [];
  List<double> walkingTimes = [];
  List<int> stepPeaks = findPeaks(stepSignal, (rate * 0.3).round(), 1.0);
  List<int> stepsPerSecond = List.filled(seconds + 1, 0);
  for (int p in stepPeaks) {
    if (p ~/ second <= seconds) stepsPerSecond[p ~/ second]++;
  }
  List<double> perSecond = [
    for (int s = 0; s < seconds; s++)
      _mean(movement.sublist(s * second, (s + 1) * second)),
  ];
  // Walking needs sustained movement (2 s average) with steps
  List<double> sustained = movingAverage(perSecond, 3);
  List<bool> walkingSecond = [
    for (int s = 0; s < seconds; s++)
      sustained[s] >= WALK_LIMIT && stepsPerSecond[s] >= 1,
  ];
  for (int s = 0; s < seconds; s++) {
    double level = perSecond[s];
    int mid = s * second + second ~/ 2;
    double g = math.sqrt(
      gx[mid] * gx[mid] + gy[mid] * gy[mid] + gz[mid] * gz[mid],
    );
    double angle = g > 0
        ? math.acos((gz[mid].abs() / g).clamp(0.0, 1.0)) * 180 / math.pi
        : 90;
    if (walkingSecond[s]) {
      walk++;
      walkingTimes.add(s.toDouble());
    } else if (level < STILL_LIMIT) {
      still++;
      if (angle < FLAT_ANGLE) flat++;
    }
    moving.add(!walkingSecond[s] && level >= MOVE_LIMIT);
  }
  // Bouts of movement: runs of moving seconds, gaps up to 2 s merged
  int bouts = 0, gap = 99;
  for (bool m in moving) {
    if (m) {
      if (gap > 2) bouts++;
      gap = 0;
    } else {
      gap++;
    }
  }

  Map<String, Object> result = {
    Measure.stillness: (100 * still / seconds).round(),
    Measure.movements: bouts,
    Measure.flat: double.parse((flat / seconds).toStringAsFixed(2)),
    Measure.upright: double.parse(
      ((still - flat) / seconds).toStringAsFixed(2),
    ),
    Measure.walking: double.parse((walk / seconds).toStringAsFixed(2)),
  };

  if (walk >= 10) {
    List<double> stepTimes = [
      for (int p in stepPeaks)
        if (walkingSecond[math.min(p ~/ second, seconds - 1)]) p / rate,
    ];
    result[Measure.steps] = stepTimes.length;
    result[Measure.cadence] = double.parse(
      (60 * stepTimes.length / walk).toStringAsFixed(1),
    );
    // Evenness within walking stretches (ignore pauses longer than 1.5 s)
    List<double> gaps = [
      for (int i = 1; i < stepTimes.length; i++)
        if (stepTimes[i] - stepTimes[i - 1] < 1.5)
          stepTimes[i] - stepTimes[i - 1],
    ];
    if (gaps.length >= 4) {
      double m = _mean(gaps);
      result[Measure.paceSteady] = (100 * (1 - (_std(gaps) / m) / 0.5))
          .round()
          .clamp(0, 100);
    }
  }

  // Breathing from motion: the slow rise and fall of the phone on the belly
  // (or chest, lap). Only while not walking.
  if (walk < seconds * 0.5) {
    int step = math.max(1, (rate / BREATH_RATE).round());
    double slowRate = rate / step; // actual rate after keeping every step-th
    List<List<double>> axes = [x, y, z];
    List<double>? best;
    double bestSpread = 0;
    for (List<double> axis in axes) {
      List<double> slow = [for (int i = 0; i < n; i += step) axis[i]];
      // Keep 0.05-1 Hz: smooth over 0.5 s, remove the 10 s trend
      List<double> smooth = movingAverage(slow, (slowRate * 0.5).round());
      List<double> trend = movingAverage(slow, (slowRate * 10).round());
      List<double> band = [
        for (int i = 0; i < slow.length; i++) smooth[i] - trend[i],
      ];
      double spread = _std(band);
      if (spread > bestSpread) {
        bestSpread = spread;
        best = band;
      }
    }
    if (best != null) {
      _addBreathing(result, best, slowRate, Measure.sourceMotion);
    }
  }
  return result;
}

/// Adds breath rate, count and steadiness from a breathing-like [signal].
void _addBreathing(
  Map<String, Object> result,
  List<double> signal,
  double rate,
  String source,
) {
  (double, double)? period = dominantPeriod(signal, rate);
  if (period == null) return;
  var (seconds, strength) = period;
  int confidence = (100 * strength).round();
  if (confidence < 30) return; // too weak to call it breathing
  double duration = signal.length / rate;
  // Needs at least 45 s and three full breaths to be worth reporting
  if (duration < 45 || duration < 3 * seconds) return;
  List<int> peaks = findPeaks(
    signal,
    (seconds * 0.6 * rate).round(),
    0.3 * _std(signal),
  );
  result[Measure.breathRate] = double.parse((60 / seconds).toStringAsFixed(1));
  result[Measure.breaths] = (duration / seconds).round();
  result[Measure.breathSource] = source;
  result[Measure.breathConfidence] = confidence;
  int? steady = _evenness([for (int p in peaks) p / rate]);
  if (steady != null) result[Measure.breathSteady] = steady;
}

// --- sound -----------------------------------------------------------------

const double SOUND_FRAME_RATE =
        20.0, // loudness values per second
    QUIET_DB =
        -65.0, // dBFS: a quiet room on most phone microphones
    NOISY_DB = -30.0; // dBFS: talking nearby

Map<String, Object> _analyzeSound(
  List<double> levels,
  List<double> envelope,
  double offset,
  List<GuidanceMark> marks,
  List<(double, double)> away,
  bool breathFromSound,
) {
  if (levels.length < SOUND_FRAME_RATE * 20) return {};
  double rate = SOUND_FRAME_RATE;
  // Leave out moments when the app itself was making a sound, and time away
  // from the app (Android silences the microphone then)
  _Ranges own = _Ranges.of(marks, (m) => m.sound);
  _Ranges gone = _Ranges(away);
  List<double> kept = [];
  List<bool> keep = [];
  for (int i = 0; i < levels.length; i++) {
    double t = offset + i / rate;
    bool skip = own.contains(t) || gone.contains(t);
    keep.add(!skip);
    if (!skip) kept.add(levels[i]);
  }
  if (kept.length < rate * 10) return {};
  double typical = percentile(kept, 0.5), loud = percentile(kept, 0.95);
  // Loud moments: well above the room's typical level, at least 1 s apart
  double limit = math.max(typical + 15, -45);
  int moments = 0, lastLoud = -999;
  for (int i = 0; i < levels.length; i++) {
    if (keep[i] && levels[i] >= limit) {
      if (i - lastLoud > rate) moments++;
      lastLoud = i;
    }
  }
  double quietness =
      100 * (NOISY_DB - typical) / (NOISY_DB - QUIET_DB) - 4 * moments;
  Map<String, Object> result = {
    Measure.noiseDb: double.parse(typical.toStringAsFixed(1)),
    Measure.peakDb: double.parse(loud.toStringAsFixed(1)),
    Measure.quiet: quietness.round().clamp(0, 100),
    Measure.loudMoments: moments,
  };

  // Breathing from sound: the rise and fall of breath noise. Skipped when the
  // app played guidance sounds (it would just measure the guide) or the app
  // was left.
  if (breathFromSound && gone.isEmpty && envelope.length == levels.length) {
    int step = math.max(1, (rate / BREATH_RATE).round());
    double slowRate = rate / step;
    List<double> slow = [
      for (int i = 0; i < envelope.length; i += step)
        math.log(envelope[i] + 1e-6),
    ];
    List<double> smooth = movingAverage(slow, (slowRate * 0.4).round());
    List<double> trend = movingAverage(slow, (slowRate * 10).round());
    _addBreathing(
      result,
      [for (int i = 0; i < slow.length; i++) smooth[i] - trend[i]],
      slowRate,
      Measure.sourceSound,
    );
  }
  return result;
}

// --- putting it together ---------------------------------------------------

/// All measurements for a session. [levels] are loudness values in dBFS and
/// [envelope] the matching breath-band loudness (linear), both at
/// [SOUND_FRAME_RATE] per second starting [soundOffset] seconds into the
/// session; leave them empty when the microphone was off. [away] are the
/// stretches (start, end in seconds) when the app was left; [guideRate] the
/// breathing pace the guide set, in breaths per minute.
Map<String, Object> analyzeSession({
  required double durationSeconds,
  List<MotionSample> motion = const [],
  List<double> levels = const [],
  List<double> envelope = const [],
  double soundOffset = 0,
  List<GuidanceMark> guidance = const [],
  List<(double, double)> away = const [],
  double? guideRate,
}) {
  double awaySeconds = away.fold(0.0, (total, a) => total + (a.$2 - a.$1));
  Map<String, Object> result = {
    Measure.version: 1,
    Measure.seconds: durationSeconds.round(),
    Measure.interruptions: away.length,
    if (away.isNotEmpty) Measure.awaySeconds: awaySeconds.round(),
    if (guideRate != null && guideRate > 0)
      Measure.guideRate: double.parse(guideRate.toStringAsFixed(1)),
  };
  Map<String, Object> moved = _analyzeMotion(motion, guidance);
  bool guidedBySound = guidance.any((m) => m.sound);
  Map<String, Object> heard = _analyzeSound(
    levels,
    envelope,
    soundOffset,
    guidance,
    away,
    !guidedBySound,
  );
  // Breathing: whichever source is more confident
  int motionConfidence = (moved[Measure.breathConfidence] as int?) ?? 0;
  int soundConfidence = (heard[Measure.breathConfidence] as int?) ?? 0;
  const List<String> breathKeys = [
    Measure.breaths,
    Measure.breathRate,
    Measure.breathSource,
    Measure.breathConfidence,
    Measure.breathSteady,
  ];
  Map<String, Object> loser = motionConfidence >= soundConfidence
      ? heard
      : moved;
  for (String key in breathKeys) {
    loser.remove(key);
  }
  result.addAll(moved);
  result.addAll(heard);
  return result;
}

// --- reading the measurements ----------------------------------------------

double _fraction(Map measures, String key) =>
    ((measures[key] as num?) ?? 0).toDouble();

bool _isWalkingType(String? type) => type == SESSION_TYPE_WALKING;

/// How well the measured movement fits [type], 0-100 (null when it can't be
/// judged, e.g. no motion data or no/other type).
int? typeFit(Map? measures, String? type) {
  if (measures == null || !measures.containsKey(Measure.stillness)) {
    return null;
  }
  double flat = _fraction(measures, Measure.flat),
      upright = _fraction(measures, Measure.upright),
      walking = _fraction(measures, Measure.walking);
  double fit;
  switch (type) {
    case SESSION_TYPE_LYING:
      fit = flat + 0.4 * upright; // phone on the belly lies flat
    case SESSION_TYPE_SITTING:
    case SESSION_TYPE_BODY_SCAN:
      fit = flat + upright; // still, phone in hand or on the lap
    case SESSION_TYPE_WALKING:
      fit = walking;
    default:
      return null;
  }
  return (100 * fit).round().clamp(0, 100);
}

/// The type the measured movement looks like, or null if unclear.
String? suggestedType(Map? measures) {
  if (measures == null || !measures.containsKey(Measure.stillness)) {
    return null;
  }
  double flat = _fraction(measures, Measure.flat),
      upright = _fraction(measures, Measure.upright),
      walking = _fraction(measures, Measure.walking);
  if (walking >= 0.5) return SESSION_TYPE_WALKING;
  if (flat + upright < 0.6) return null;
  bool bellyBreathing =
      measures[Measure.breathSource] == Measure.sourceMotion &&
      ((measures[Measure.breathConfidence] as num?) ?? 0) >= 50;
  if (flat >= 0.6 && bellyBreathing) return SESSION_TYPE_LYING;
  return SESSION_TYPE_SITTING;
}

/// Measured calm score, 0-100, for a session of [type]: stillness (or an
/// even walking pace), steady breathing and a quiet environment, minus
/// interruptions. Null when nothing was measured.
int? calmScore(Map? measures, String? type) {
  if (measures == null) return null;
  num? read(String key) => measures[key] as num?;
  List<(double, double)> parts = []; // (score, weight)
  if (_isWalkingType(type)) {
    num? pace = read(Measure.paceSteady);
    if (pace != null) parts.add((pace.toDouble(), 0.6));
  } else {
    num? still = read(Measure.stillness);
    if (still != null) parts.add((still.toDouble(), 0.5));
    num? breath = read(Measure.breathSteady);
    if (breath != null) parts.add((breath.toDouble(), 0.2));
  }
  num? quiet = read(Measure.quiet);
  if (quiet != null) parts.add((quiet.toDouble(), 0.3));
  if (parts.isEmpty) return null;
  double weights = parts.fold(0.0, (total, p) => total + p.$2);
  double score = parts.fold(0.0, (total, p) => total + p.$1 * p.$2) / weights;
  int interruptions = (read(Measure.interruptions) ?? 0).toInt();
  score -= 10 * math.min(interruptions, 3);
  return score.round().clamp(0, 100);
}
