import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:lucid/constants.dart';
import 'package:lucid/session_measure.dart';

const double G = 9.81, RATE = 50; // accelerometer readings per second

/// Simulated accelerometer: [gravity] gives the phone's tilt, [extra] adds
/// movement at time t. Readings arrive at ~50 Hz with jitter and noise.
List<MotionSample> simulate(
  double seconds,
  List<double> gravity,
  List<double> Function(double t) extra, {
  int seed = 1,
  double noise = 0.02,
}) {
  math.Random random = math.Random(seed);
  List<MotionSample> samples = [];
  double t = 0;
  while (t < seconds) {
    List<double> e = extra(t);
    double n() => (random.nextDouble() - 0.5) * 2 * noise;
    samples.add(
      MotionSample(
        t,
        gravity[0] + e[0] + n(),
        gravity[1] + e[1] + n(),
        gravity[2] + e[2] + n(),
      ),
    );
    t += 1 / RATE + (random.nextDouble() - 0.5) * 0.004;
  }
  return samples;
}

List<double> none(double t) => [0, 0, 0];

void main() {
  group('Session measurements', () {
    test('lying down, phone on the belly, 6 breaths per minute', () {
      // Flat, screen up; each breath tilts the phone a little
      List<MotionSample> motion = simulate(300, [0, 0, G], (t) {
        double breath = math.sin(2 * math.pi * t / 10);
        return [0.15 * breath, 0.05 * breath, 0];
      });
      Map<String, Object> m = analyzeSession(
        durationSeconds: 300,
        motion: motion,
      );

      expect((m[Measure.stillness] as int) >= 95, isTrue);
      expect(m[Measure.movements], 0);
      expect((m[Measure.flat] as double) >= 0.9, isTrue);
      expect(m[Measure.breathSource], Measure.sourceMotion);
      expect(((m[Measure.breathRate] as double) - 6).abs() <= 0.5, isTrue);
      expect(((m[Measure.breaths] as int) - 30).abs() <= 3, isTrue);
      expect((m[Measure.breathConfidence] as int) >= 50, isTrue);
      expect((m[Measure.breathSteady] as int) >= 70, isTrue);

      expect(suggestedType(m), SESSION_TYPE_LYING);
      expect(typeFit(m, SESSION_TYPE_LYING)! >= 90, isTrue);
      expect(typeFit(m, SESSION_TYPE_WALKING), 0);
      expect(calmScore(m, SESSION_TYPE_LYING)! >= 85, isTrue);
    });

    test('sitting, phone in the hand, three fidgets', () {
      // Tilted about 45 degrees; short bursts of movement at 60, 150, 240 s
      double tilt = G / math.sqrt2;
      List<MotionSample> motion = simulate(300, [0, tilt, tilt], (t) {
        for (double at in [60.0, 150.0, 240.0]) {
          if (t >= at && t < at + 2) {
            return [2 * math.sin(2 * math.pi * 3 * t), 1.5, 0];
          }
        }
        return [0, 0, 0];
      }, noise: 0.05);
      Map<String, Object> m = analyzeSession(
        durationSeconds: 300,
        motion: motion,
      );

      expect(m[Measure.movements], 3);
      expect((m[Measure.stillness] as int) >= 90, isTrue);
      expect((m[Measure.flat] as double) <= 0.05, isTrue);
      expect((m[Measure.upright] as double) >= 0.9, isTrue);
      expect(m.containsKey(Measure.steps), isFalse);
      expect(suggestedType(m), SESSION_TYPE_SITTING);
      expect(typeFit(m, SESSION_TYPE_SITTING)! >= 90, isTrue);
      expect(typeFit(m, SESSION_TYPE_LYING)! < 50, isTrue);
    });

    test('walking, phone in the pocket, 108 steps per minute', () {
      // Upright in the pocket; a bounce with every step (1.8 per second)
      List<MotionSample> motion = simulate(180, [0, G, 0], (t) {
        double phase = 2 * math.pi * 1.8 * t;
        return [0.8 * math.sin(phase / 2), 3 * math.sin(phase), 0.5];
      }, noise: 0.2);
      Map<String, Object> m = analyzeSession(
        durationSeconds: 180,
        motion: motion,
      );

      expect((m[Measure.walking] as double) >= 0.8, isTrue);
      expect(((m[Measure.steps] as int) - 324).abs() <= 32, isTrue);
      expect(((m[Measure.cadence] as double) - 108).abs() <= 8, isTrue);
      expect((m[Measure.paceSteady] as int) >= 70, isTrue);
      expect(suggestedType(m), SESSION_TYPE_WALKING);
      expect(typeFit(m, SESSION_TYPE_WALKING)! >= 80, isTrue);
      expect(typeFit(m, SESSION_TYPE_SITTING)! <= 20, isTrue);
      expect(calmScore(m, SESSION_TYPE_WALKING)! >= 70, isTrue);
    });

    test("the app's own vibrations are not counted as movement", () {
      // Lying still; the phone buzzes for 0.1 s every 8 s
      bool buzzing(double t) => t % 8 < 0.1;
      List<MotionSample> motion = simulate(240, [0, 0, G], (t) {
        double buzz = buzzing(t) ? 4 * math.sin(2 * math.pi * 170 * t) : 0;
        return [buzz, buzz, buzz];
      });
      List<GuidanceMark> marks = [
        for (double at = 0; at < 240; at += 8)
          GuidanceMark(at, at + 0.4, vibration: true),
      ];

      Map<String, Object> guided = analyzeSession(
        durationSeconds: 240,
        motion: motion,
        guidance: marks,
      );
      Map<String, Object> unguided = analyzeSession(
        durationSeconds: 240,
        motion: motion,
      );
      expect(guided[Measure.movements], 0);
      expect((guided[Measure.stillness] as int) >= 95, isTrue);
      // Without knowing about them, the buzzes would look like fidgeting
      expect((unguided[Measure.movements] as int) > 0, isTrue);
    });

    test('environment loudness and loud moments', () {
      // A quiet room around -62 dBFS, three loud moments of half a second
      math.Random random = math.Random(3);
      List<double> levels = [
        for (int i = 0; i < 20 * 120; i++)
          () {
            double t = i / 20;
            bool loud = [30.0, 60.0, 90.0].any((at) => t >= at && t < at + 0.5);
            return loud ? -25.0 : -62 + (random.nextDouble() - 0.5) * 4;
          }(),
      ];
      Map<String, Object> m = analyzeSession(
        durationSeconds: 120,
        levels: levels,
        envelope: [for (double l in levels) math.pow(10, l / 20).toDouble()],
      );
      expect(m[Measure.loudMoments], 3);
      expect(((m[Measure.noiseDb] as double) + 62).abs() <= 1, isTrue);
      expect(((m[Measure.quiet] as int) - 79).abs() <= 4, isTrue);
      expect(m.containsKey(Measure.stillness), isFalse);
      expect(typeFit(m, SESSION_TYPE_SITTING), isNull);
    });

    test('breathing heard by the microphone, unless the app plays tones', () {
      // Breath noise rising and falling 12 times a minute
      math.Random random = math.Random(4);
      List<double> envelope = [
        for (int i = 0; i < 20 * 180; i++)
          0.002 *
                  (1.2 + math.sin(2 * math.pi * 0.2 * i / 20)) *
                  (1 + 0.1 * random.nextDouble()) +
              0.0005,
      ];
      List<double> levels = [
        for (double e in envelope) 20 * math.log(e) / math.ln10,
      ];

      Map<String, Object> heard = analyzeSession(
        durationSeconds: 180,
        levels: levels,
        envelope: envelope,
      );
      expect(heard[Measure.breathSource], Measure.sourceSound);
      expect(((heard[Measure.breathRate] as double) - 12).abs() <= 1, isTrue);

      Map<String, Object> withTones = analyzeSession(
        durationSeconds: 180,
        levels: levels,
        envelope: envelope,
        guidance: [GuidanceMark(10, 11, sound: true)],
      );
      expect(withTones.containsKey(Measure.breathRate), isFalse);
    });

    test('time away from the app is counted and left out of loudness', () {
      // Quiet room; Android silences the microphone while the app is left
      List<double> levels = [
        for (int i = 0; i < 20 * 120; i++)
          (i / 20 >= 40 && i / 20 < 70) ? -120.0 : -50.0,
      ];
      Map<String, Object> m = analyzeSession(
        durationSeconds: 120,
        levels: levels,
        away: [(40, 70)],
        guideRate: 6,
      );
      expect(m[Measure.interruptions], 1);
      expect(m[Measure.awaySeconds], 30);
      expect(m[Measure.guideRate], 6.0);
      expect(((m[Measure.noiseDb] as double) + 50).abs() <= 0.5, isTrue);
    });

    test('no breathing reported from short or noisy recordings', () {
      Map<String, Object> short = analyzeSession(
        durationSeconds: 30,
        motion: simulate(30, [0, 0, G], none),
      );
      expect(short.containsKey(Measure.breathRate), isFalse);
      Map<String, Object> noise = analyzeSession(
        durationSeconds: 300,
        motion: simulate(300, [0, 1.5, 9.69], none, noise: 0.04),
      );
      expect(noise.containsKey(Measure.breathRate), isFalse);
      // Still and flat but no breathing seen: sitting with the phone on the lap
      expect(suggestedType(noise), SESSION_TYPE_SITTING);
    });

    test('a restless session suggests no type and fits poorly', () {
      // Picked up and handled for 10 s out of every 20
      List<MotionSample> motion = simulate(300, [0, 0, G], (t) {
        if (t % 20 < 10) return [3 * math.sin(2 * math.pi * 2 * t), 2, 1];
        return [0, 0, 0];
      });
      Map<String, Object> m = analyzeSession(
        durationSeconds: 300,
        motion: motion,
      );
      expect((m[Measure.stillness] as int) <= 60, isTrue);
      expect(suggestedType(m), isNull);
      expect(typeFit(m, SESSION_TYPE_LYING)! < 60, isTrue);
      expect(typeFit(m, SESSION_TYPE_OTHER), isNull);
    });

    test('calm score combines what was measured, minus interruptions', () {
      Map<String, Object> m = {
        Measure.stillness: 90,
        Measure.breathSteady: 80,
        Measure.quiet: 70,
        Measure.interruptions: 0,
      };
      // (90*0.5 + 80*0.2 + 70*0.3) / 1.0 = 82
      expect(calmScore(m, SESSION_TYPE_SITTING), 82);
      m[Measure.interruptions] = 2;
      expect(calmScore(m, SESSION_TYPE_SITTING), 62);
      expect(calmScore({Measure.interruptions: 0}, null), isNull);
    });
  });
}
