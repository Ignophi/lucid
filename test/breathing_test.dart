import 'package:flutter_test/flutter_test.dart';

import 'package:lucid/breathing.dart';

Duration ms(int value) => Duration(milliseconds: value);
Duration s(double value) => Duration(milliseconds: (value * 1000).round());

void main() {
  group('Breathing guide', () {
    // 4-7-8: inhale 4 s, hold 7 s, exhale 8 s
    BreathPattern pattern478 = BreathPattern([4000, 7000, 0], [8000, 0, 0]);

    test('phases follow the pattern', () {
      expect(pattern478.breath, 19000);
      expect(pattern478.phaseAt(0).$1, BreathPhase.inhale);
      expect(pattern478.phaseAt(3999).$1, BreathPhase.inhale);
      expect(pattern478.phaseAt(4000), (BreathPhase.inhaleHold, 4000));
      expect(pattern478.phaseAt(11000), (BreathPhase.exhale, 11000));
      expect(pattern478.phaseAt(18999).$1, BreathPhase.exhale);
      // Parts of length 0 are skipped
      BreathPattern sigh = BreathPattern([2000, 0, 1000], [6000, 0, 0]);
      expect(sigh.phaseAt(2000).$1, BreathPhase.inhaleLast);
      expect(sigh.phaseAt(3000).$1, BreathPhase.exhale);
    });

    test('the circle grows, holds and shrinks', () {
      expect(pattern478.scaleAt(0), 0.0);
      expect(pattern478.scaleAt(2000), 0.5);
      expect(pattern478.scaleAt(4000), 1.0);
      expect(pattern478.scaleAt(9000), 1.0); // holding
      expect(pattern478.scaleAt(15000), 0.5);
      expect(pattern478.scaleAt(19000), 0.0);
      BreathPattern sigh = BreathPattern([2000, 500, 1000], [6000, 0, 0]);
      expect(sigh.scaleAt(2250), closeTo(2 / 3, 1e-9)); // hold after 2 of 3 s
      expect(sigh.scaleAt(3500), 1.0);
    });

    test('the circle eases in and out of each part', () {
      expect(pattern478.easedScaleAt(0), 0.0);
      expect(pattern478.easedScaleAt(2000), closeTo(0.5, 1e-9));
      expect(pattern478.easedScaleAt(1000), lessThan(0.25)); // slow start
      expect(pattern478.easedScaleAt(4000), 1.0);
      expect(pattern478.easedScaleAt(8000), 1.0); // holding
      expect(pattern478.easedScaleAt(15000), closeTo(0.5, 1e-9));
      expect(pattern478.easedScaleAt(19000), 0.0);
    });

    test('time comes from the clock, not from timer ticks', () {
      BreathingSession session = BreathingSession(
        pattern: pattern478,
        duration: const Duration(minutes: 2),
      );
      // 120 s is not a whole number of 19 s breaths: it ends after 7
      expect(session.length, s(133));

      // Jumping straight to any moment gives the right state, e.g. after
      // the phone was busy or the app was in the background
      BreathingState state = session.stateAt(s(50));
      expect(state.breath, 2);
      expect(state.breaths, 2);
      expect(state.phase, BreathPhase.exhale); // 12 s into the third breath
      expect(state.intoPhase, s(1));
      expect(state.phaseLeft, s(7)); // exhale lasts 8 s
      expect(state.cycleProgress, closeTo(12 / 19, 1e-9));
      expect(state.remaining, s(70));
      expect(state.finished, isFalse);

      // Time up, last breath still finishing
      state = session.stateAt(s(125));
      expect(state.remaining, Duration.zero);
      expect(state.finished, isFalse);

      // Done, even if checked long after
      state = session.stateAt(const Duration(minutes: 30));
      expect(state.finished, isTrue);
      expect(state.breaths, 7);
    });

    test('a duration that fits whole breaths ends right on time', () {
      BreathingSession session = BreathingSession(
        pattern: BreathPattern([4000, 0, 0], [4000, 0, 0]),
        duration: const Duration(seconds: 120),
      );
      expect(session.length, s(120));
      expect(session.stateAt(s(119.9)).finished, isFalse);
      BreathingState end = session.stateAt(s(120));
      expect(end.finished, isTrue);
      expect(end.breaths, 15);
      expect(session.pattern.breathsPerMinute, 7.5);
    });

    test('works without a breathing pattern', () {
      BreathingSession session = BreathingSession(
        pattern: BreathPattern([0, 0, 0], [0, 0, 0]),
        duration: const Duration(seconds: 60),
      );
      expect(session.length, s(60));
      expect(session.stateAt(s(30)).finished, isFalse);
      expect(session.stateAt(s(60)).finished, isTrue);
      expect(session.stateAt(s(60)).breaths, 0);
    });
  });
}
