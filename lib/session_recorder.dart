// Records the phone's sensors while a session runs and turns them into
// measurements when it ends (see session_measure.dart).
//
// - Motion: the accelerometer, read about 50 times a second. No permission
//   needed and very little battery.
// - Sound (only when turned on in Measurements): the microphone, processed
//   on the fly into loudness values 20 times a second. No audio is stored.
//
// The app's own guidance (vibrations, tones, spoken cues) is marked so the
// analysis can leave it out, and time away from the app is noted.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:lucid/session_measure.dart';

class SessionRecorder {
  SessionRecorder({this.motion = true, this.sound = false});

  /// Whether to record the accelerometer and the microphone.
  final bool motion, sound;

  /// Sensors are only read on Android phones (not in tests or on desktop).
  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// Asks for microphone access (shows the system prompt if needed).
  static Future<bool> requestMicrophone() async {
    if (!supported) return false;
    AudioRecorder recorder = AudioRecorder();
    try {
      return await recorder.hasPermission();
    } catch (e) {
      debugPrint("microphone permission: $e");
      return false;
    } finally {
      recorder.dispose();
    }
  }

  // Microphone processing
  static const int _sampleRate = 16000,
      _frame = _sampleRate ~/ 20; // 50 ms per loudness value
  static const double _highPassHz = 300; // breath noise sits above hum/rumble

  DateTime _startedAt = DateTime.now();
  bool _running = false;
  // Pauses are cut out of the timeline, as if they never happened
  Duration _pausedTotal = Duration.zero;
  DateTime? _pausedSince;

  StreamSubscription<AccelerometerEvent>? _motionSubscription;
  final List<MotionSample> _motion = [];
  double _lastMotionTime = 0;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _soundSubscription;
  final List<double> _levels = [], _envelope = [];
  double? _soundOffset;
  int? _oddByte; // a sample split between two chunks
  double _sumSquares = 0, _sumSquaresHigh = 0, _previousIn = 0, _high = 0;
  int _inFrame = 0;

  final List<GuidanceMark> _guidance = [];
  final List<(double, double)> _away = [];
  double? _awaySince;

  // Seconds of session since the start, from the clock (keeps counting while
  // asleep), not counting pauses
  double _sinceStart(DateTime time) =>
      (time.difference(_startedAt) - _pausedTotal).inMicroseconds / 1e6;
  double get _now => _sinceStart(DateTime.now());
  bool get _paused => _pausedSince != null;

  /// The session was paused: nothing is recorded until [resume].
  void pause() {
    if (_running) _pausedSince ??= DateTime.now();
  }

  void resume() {
    DateTime? since = _pausedSince;
    if (since == null) return;
    _pausedSince = null;
    _pausedTotal += DateTime.now().difference(since);
  }

  Future<void> start() async {
    if (_running || !supported) return;
    _running = true;
    _startedAt = DateTime.now();
    if (motion) {
      try {
        _motionSubscription =
            accelerometerEventStream(
              samplingPeriod: SensorInterval.gameInterval,
            ).listen(
              _onMotion,
              onError: (Object e) => debugPrint("accelerometer: $e"),
              cancelOnError: true,
            );
      } catch (e) {
        debugPrint("accelerometer: $e");
      }
    }
    if (sound) {
      await _startSound();
    }
  }

  void _onMotion(AccelerometerEvent event) {
    if (_paused) return;
    // The event's own timestamp is more accurate than when it arrives
    double t = _sinceStart(event.timestamp);
    if (t < _lastMotionTime || t > _now + 5) t = _now;
    _lastMotionTime = t;
    _motion.add(MotionSample(t, event.x, event.y, event.z));
  }

  Future<void> _startSound() async {
    AudioRecorder recorder = AudioRecorder();
    try {
      if (!await recorder.hasPermission(request: false)) {
        debugPrint("microphone: no permission");
        recorder.dispose();
        return;
      }
      Stream<Uint8List> stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
          // No automatic gain or noise suppression: loudness stays honest
          androidConfig: AndroidRecordConfig(
            audioSource: AndroidAudioSource.voiceRecognition,
            manageBluetooth: false,
          ),
          audioInterruption: AudioInterruptionMode.none,
        ),
      );
      _recorder = recorder;
      _soundSubscription = stream.listen(
        _onSound,
        onError: (Object e) => debugPrint("microphone: $e"),
      );
    } catch (e) {
      debugPrint("microphone: $e");
      recorder.dispose();
    }
  }

  void _onSound(Uint8List bytes) {
    if (!_running || _paused) return;
    _soundOffset ??= math.max(0.0, _now - bytes.length / 2 / _sampleRate);
    // RC high-pass filter coefficient
    const double dt = 1 / _sampleRate, rc = 1 / (2 * math.pi * _highPassHz);
    const double alpha = rc / (rc + dt);
    int i = 0;
    void add(int low, int high) {
      int value = low | (high << 8);
      if (value >= 0x8000) value -= 0x10000; // signed 16 bit
      double x = value / 32768.0;
      _high = alpha * (_high + x - _previousIn);
      _previousIn = x;
      _sumSquares += x * x;
      _sumSquaresHigh += _high * _high;
      if (++_inFrame == _frame) {
        double rms = math.sqrt(_sumSquares / _frame);
        _levels.add(20 * math.log(math.max(rms, 1e-6)) / math.ln10);
        _envelope.add(math.sqrt(_sumSquaresHigh / _frame));
        _sumSquares = 0;
        _sumSquaresHigh = 0;
        _inFrame = 0;
      }
    }

    if (_oddByte != null && bytes.isNotEmpty) {
      add(_oddByte!, bytes[0]);
      _oddByte = null;
      i = 1;
    }
    for (; i + 1 < bytes.length; i += 2) {
      add(bytes[i], bytes[i + 1]);
    }
    if (i < bytes.length) _oddByte = bytes[i];
  }

  /// The phone is about to vibrate for [ms] milliseconds.
  void markVibration(int ms) {
    if (!_running || ms <= 0) return;
    double t = _now;
    _guidance.add(GuidanceMark(t, t + ms / 1000 + 0.3, vibration: true));
  }

  /// The app is about to play a sound (a tone or a spoken cue).
  void markSound(double seconds) {
    if (!_running) return;
    double t = _now;
    _guidance.add(GuidanceMark(t, t + seconds, sound: true));
  }

  /// The user left the app (another app came to the front).
  void leftApp() {
    if (_running && !_paused) _awaySince ??= _now;
  }

  /// The app is back in front.
  void returned() {
    double? since = _awaySince;
    _awaySince = null;
    // Ignore blips (e.g. the notification shade pulled down briefly)
    if (_running && since != null && _now - since >= 3) {
      _away.add((since, _now));
    }
  }

  Future<void> _stopSensors() async {
    if (!_running) return;
    resume();
    returned();
    _running = false;
    await _motionSubscription?.cancel();
    _motionSubscription = null;
    await _soundSubscription?.cancel();
    _soundSubscription = null;
    AudioRecorder? recorder = _recorder;
    _recorder = null;
    if (recorder != null) {
      try {
        await recorder.stop();
      } catch (e) {
        debugPrint("microphone: $e");
      }
      recorder.dispose();
    }
  }

  /// Stops recording (the data is kept for [finish]).
  Future<void> stop() => _stopSensors();

  /// Stops recording and works out the measurements (in the background, so
  /// the screen doesn't stutter). Null when nothing could be measured.
  Future<Map<String, dynamic>?> finish({
    required double durationSeconds,
    double? guideRate,
  }) async {
    await _stopSensors();
    if (_motion.isEmpty && _levels.isEmpty) return null;
    // Copy into locals so only plain data is sent to the background isolate
    List<MotionSample> motion = List.of(_motion);
    List<double> levels = List.of(_levels), envelope = List.of(_envelope);
    List<GuidanceMark> guidance = List.of(_guidance);
    List<(double, double)> away = List.of(_away);
    double offset = _soundOffset ?? 0;
    _motion.clear();
    _levels.clear();
    _envelope.clear();
    try {
      Map<String, Object> result = await _analyze(
        durationSeconds,
        motion,
        levels,
        envelope,
        offset,
        guidance,
        away,
        guideRate,
      );
      // Too short to measure anything (under about 20 s)
      bool measured =
          result.containsKey(Measure.stillness) ||
          result.containsKey(Measure.noiseDb);
      return measured ? result : null;
    } catch (e) {
      debugPrint("measurements: $e");
      return null;
    }
  }

  // Static, so the background isolate only receives the data it needs
  static Future<Map<String, Object>> _analyze(
    double durationSeconds,
    List<MotionSample> motion,
    List<double> levels,
    List<double> envelope,
    double offset,
    List<GuidanceMark> guidance,
    List<(double, double)> away,
    double? guideRate,
  ) => Isolate.run(
    () => analyzeSession(
      durationSeconds: durationSeconds,
      motion: motion,
      levels: levels,
      envelope: envelope,
      soundOffset: offset,
      guidance: guidance,
      away: away,
      guideRate: guideRate,
    ),
  );
}
