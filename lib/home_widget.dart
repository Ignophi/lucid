import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vibration/vibration.dart';
import 'package:hive_ce/hive.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:collection/collection.dart';

import 'package:lucid/android_system.dart';
import 'package:lucid/breath_colors.dart';
import 'package:lucid/breath_wave.dart';
import 'package:lucid/breathing.dart';
import 'package:lucid/constants.dart';
import 'package:lucid/format.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/session_recorder.dart';
import 'package:lucid/theme.dart';
import 'package:lucid/utils.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

/// The meditation screen: what to do now (with the seconds left), the
/// breathing circle in the color of the current part of the breath, the
/// breathing wave with a dot showing where you are in this breath, the time
/// left, the breath count and the session's progress.
/// Opened by the Meditate button; the session starts right away (unless
/// [autoStart] is false). When the session ends (time is up, Stop, or the
/// back button) it is saved and this screen closes, returning the [Session].
/// With [measureMotion] / [measureSound] the phone's sensors are recorded
/// during the session and the measurements saved with it.
///
/// All timing comes from the clock (see breathing.dart), and on Android a
/// foreground service keeps the session going with the screen off or while
/// another app is open, so the timer never freezes.
class HomeWidget extends StatefulWidget {
  const HomeWidget({
    super.key,
    required this.preferences,
    required this.sessions,
    this.autoStart = true,
    this.measureMotion = false,
    this.measureSound = false,
  });

  final Box preferences, sessions;
  final bool autoStart, measureMotion, measureSound;

  // These static variables are used with flutter tests
  static String keyStatusText = "Status Text";
  static const String keyPause = "Pause";
  static int totalSessions = 200;

  @override
  State<HomeWidget> createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // How often the guide checks the clock (cues, countdown, end)
  static const Duration _tickInterval = Duration(milliseconds: 50);
  // A cue more than this late (e.g. the phone was asleep) is skipped
  static const Duration _cueLateLimit = Duration(milliseconds: 1500);

  bool _isRunning = false,
      _paused = false,
      _finishing = false,
      _ringVisible = false,
      _hasVibrator = false,
      _hasCustomVibrate = false,
      _hasWakelock = false,
      _hasSpeak = false;
  late Duration _remaining;
  late String _status, _preferenceName;
  late FlutterTts _tts;
  late AudioPlayer _player;
  int _breaths = 0;

  // The running session and its breathing guide
  Session? _session;
  BreathingSession? _guide;
  // Paused time doesn't count: it is left out of the session and the guide
  Duration _pausedTotal = Duration.zero;
  DateTime? _pausedAt;
  (int, BreathPhase)? _lastPhase;
  Timer? _timer;
  // Moves the circle smoothly, every frame (only while the screen shows)
  late final Ticker _ticker;
  final ValueNotifier<double> _scale = ValueNotifier<double>(0.0),
      _cycle =
          ValueNotifier<double>(0.0), // where in this breath
      _progress = ValueNotifier<double>(0.0); // how far through the session
  BreathPhase _phase = BreathPhase.inhale;
  int _phaseLeft = 0; // whole seconds left of the current part
  SessionRecorder? _recorder;

  @override
  initState() {
    debugPrint("$widget.initState");
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((_) => _updateCircle());
    _initVibrator();
    _initWakeLock();
    _initSpeak();
    _initAudio();
    _init();
    super.initState();
    if (widget.autoStart) {
      // Start once the screen is shown
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isRunning) {
          _buttonPressed();
        }
      });
    }
  }

  @override
  void dispose() {
    debugPrint("$widget.dispose");
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _ticker.dispose();
    _scale.dispose();
    _cycle.dispose();
    _progress.dispose();
    if (_session != null) {
      // Closed mid-session (e.g. the app was shut): release everything
      _wakeLock(false);
      AndroidSystem.stopSession();
    }
    _recorder?.stop();
    _player.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _checkLeftApp();
    } else if (state == AppLifecycleState.resumed) {
      _recorder?.returned();
      _tick(); // catch up the display right away
    }
  }

  /// Leaving the app mid-session is noted for the measurements; turning the
  /// screen off is not (meditating with the screen off is fine).
  Future<void> _checkLeftApp() async {
    if (_recorder == null) return;
    // Give the screen a moment to report that it went off
    await Future.delayed(const Duration(milliseconds: 300));
    if (await AndroidSystem.isScreenOn()) {
      _recorder?.leftApp();
    }
  }

  /// The active preference (the defaults if none has been saved yet).
  Preference get _preference => widget.preferences.isEmpty
      ? Preference.getDefaultPref()
      : widget.preferences.get(0);

  void _init() {
    _status = "";
    _update();
  }

  Future<void> _initVibrator() async {
    try {
      _hasVibrator = await Vibration.hasVibrator();
      _hasCustomVibrate = await Vibration.hasCustomVibrationsSupport();
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _initSpeak() async {
    try {
      _tts = FlutterTts();
      await _tts.awaitSpeakCompletion(false);
      _hasSpeak = true;
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _initAudio() {
    AudioCache.instance = AudioCache(prefix: "audio/");
    _player = AudioPlayer();
  }

  Future<void> _initWakeLock() async {
    try {
      await WakelockPlus.enabled;
      _hasWakelock = true;
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future _speak(String text) async {
    if (_hasSpeak) {
      _recorder?.markSound(2.5);
      await _tts.speak(text);
    }
  }

  void _wakeLock(bool enable) {
    if (_hasWakelock) {
      WakelockPlus.toggle(enable: enable);
    }
  }

  void _update() {
    Preference preference = _preference;
    _remaining = Duration(seconds: preference.duration);
    _preferenceName = preference.name.isEmpty ? APP_NAME : preference.name;
  }

  Future<void> _vibrate(int ms) async {
    if (_hasVibrator && ms > 0) {
      _recorder?.markVibration(_hasCustomVibrate ? ms : 500);
      if (_hasCustomVibrate) {
        await Vibration.vibrate(duration: ms);
      } else {
        await Vibration.vibrate();
      }
    }
  }

  Future<void> _onDuration(Session session) async {
    Preference preference = _preference;

    _vibrate(preference.vibrateDuration);

    Duration diff = roundDuration(session.end.difference(session.start));
    String duration = getDurationString(diff);
    int breaths = session.breaths;
    String text = "$duration ${AppLocalizations.of(context).session}";
    if (breaths == 1) {
      text += ", $breaths ${AppLocalizations.of(context).breath}";
    } else {
      text += ", $breaths ${AppLocalizations.of(context).breaths}";
    }
    if (session.heartrates != null) {
      int average = session.heartrates!.average.toInt();
      if (average > 0) {
        text += ", $average ${AppLocalizations.of(context).heartrate}";
      }
    }

    if (preference.durationTts) {
      await _speak(text);
    }
  }

  Future<void> _onBreath(String text, [int pulses = 1]) async {
    Preference preference = _preference;

    for (int i = 0; i < pulses; i++) {
      _vibrate(preference.vibrateBreath ~/ pulses);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (preference.breathTts) {
      await _speak(text);
    }
  }

  Future<void> _play(String audio) async {
    if (audio != AUDIO_NONE) {
      _recorder?.markSound(2.5); // tones last up to 2 s
    }
    await play(_player, audio);
  }

  String _phaseText(BreathPhase phase) {
    AppLocalizations l10n = AppLocalizations.of(context);
    switch (phase) {
      case BreathPhase.inhale:
      case BreathPhase.inhaleLast:
        return l10n.inhale;
      case BreathPhase.inhaleHold:
      case BreathPhase.exhaleHold:
        return l10n.hold;
      case BreathPhase.exhale:
      case BreathPhase.exhaleLast:
        return l10n.exhale;
    }
  }

  /// Vibration, spoken word and tone at the start of each part of a breath.
  void _cue(BreathPhase phase) {
    Preference preference = _preference;
    String text = _phaseText(phase);
    switch (phase) {
      case BreathPhase.inhale:
        _onBreath(text);
        _play(preference.audio[0]);
      case BreathPhase.inhaleHold:
        _onBreath(text);
        _play(preference.audio[2]);
      case BreathPhase.inhaleLast:
        _onBreath(text);
      case BreathPhase.exhale:
        _onBreath(text, 2);
        _play(preference.audio[1]);
      case BreathPhase.exhaleHold:
        _onBreath(text);
        _play(preference.audio[3]);
      case BreathPhase.exhaleLast:
        _onBreath(text);
    }
  }

  void _addSession(Session session) {
    widget.sessions.add(session).then((value) {
      debugPrint("added session:$session");
    });
  }

  /// Saves the finished session and closes this screen, handing the session
  /// back so its review can be opened. (Hive links the session to its box as
  /// soon as add() is called, so it can be updated right away.) When sensors
  /// were recorded, the measurements are worked out first.
  Future<void> _finish(Session session) async {
    if (_finishing) return;
    SessionRecorder? recorder = _recorder;
    _recorder = null;
    if (recorder != null) {
      setState(() => _finishing = true);
      await recorder.stop(); // stop the sensors before the end cue
    }
    if (mounted) {
      _onDuration(session);
    }
    if (recorder != null) {
      Preference preference = _preference;
      session.measurements = await recorder.finish(
        durationSeconds:
            session.end.difference(session.start).inMilliseconds / 1000,
        guideRate: BreathPattern(
          preference.inhale,
          preference.exhale,
        ).breathsPerMinute,
      );
    }
    _addSession(session);
    if (mounted) {
      Navigator.of(context).pop(session);
    }
  }

  void _buttonPressed() {
    if (_isRunning) {
      _stop();
    } else if (!_finishing) {
      _start();
    }
  }

  /// Time meditated since the start, not counting pauses.
  Duration _elapsed([DateTime? at]) {
    Session? session = _session;
    if (session == null) return Duration.zero;
    DateTime now = at ?? DateTime.now();
    Duration paused = _pausedTotal;
    DateTime? pausedAt = _pausedAt;
    if (pausedAt != null) paused += now.difference(pausedAt);
    return now.difference(session.start) - paused;
  }

  /// Pause: the guide, the cues and the measurements wait; the time left
  /// stays where it is.
  void _pause() {
    if (!_isRunning || _paused) return;
    setState(() {
      _paused = true;
      _pausedAt = DateTime.now();
      _status = AppLocalizations.of(context).paused;
    });
    _ticker.stop();
    _recorder?.pause();
    AndroidSystem.startSession(
      title: _preferenceName,
      text: AppLocalizations.of(context).paused,
      microphone: widget.measureSound,
    );
  }

  void _resume() {
    DateTime? pausedAt = _pausedAt;
    BreathingSession? guide = _guide;
    if (!_paused || pausedAt == null || guide == null) return;
    _pausedTotal += DateTime.now().difference(pausedAt);
    _pausedAt = null;
    _recorder?.resume();
    setState(() {
      _paused = false;
      _lastPhase = null; // cue the current part again
    });
    AndroidSystem.startSession(
      title: _preferenceName,
      text: AppLocalizations.of(context).sessionInProgress,
      endsAt: DateTime.now().add(guide.length - _elapsed()),
      microphone: widget.measureSound,
    );
    _ticker.start();
    _tick();
  }

  void _start() {
    Preference preference = _preference;
    _update();
    DateTime now = DateTime.now();
    BreathingSession guide = BreathingSession(
      pattern: BreathPattern(preference.inhale, preference.exhale),
      duration: Duration(seconds: preference.duration),
    );
    setState(() {
      _isRunning = true;
      _paused = false;
      _pausedTotal = Duration.zero;
      _pausedAt = null;
      _session = Session(start: now);
      _guide = guide;
      _lastPhase = null;
      _breaths = 0;
      _remaining = guide.duration;
    });
    _wakeLock(true);
    if ((widget.measureMotion || widget.measureSound) &&
        SessionRecorder.supported) {
      _recorder = SessionRecorder(
        motion: widget.measureMotion,
        sound: widget.measureSound,
      )..start();
    }
    AndroidSystem.startSession(
      title: _preferenceName,
      text: AppLocalizations.of(context).sessionInProgress,
      endsAt: now.add(guide.length),
      microphone: widget.measureSound,
    );
    _ticker.start();
    _timer = Timer.periodic(_tickInterval, (_) => _tick());
    _tick();
  }

  /// Stop pressed (or back): ends now, counting the breaths completed. The
  /// session lasts the time meditated (pauses left out).
  void _stop() {
    Session? session = _session;
    BreathingSession? guide = _guide;
    if (session == null || guide == null) return;
    Duration elapsed = _elapsed();
    _end(session.start.add(elapsed), guide.stateAt(elapsed).breaths);
  }

  /// Checks the clock: gives the cue when a new part of a breath starts,
  /// updates the countdown and ends the session when it is complete.
  void _tick() {
    Session? session = _session;
    BreathingSession? guide = _guide;
    if (session == null || guide == null || !mounted || _paused) return;
    BreathingState state = guide.stateAt(_elapsed());
    if (state.finished) {
      // Ends at the planned time, even if noticed late
      _end(session.start.add(guide.length), state.breaths);
      return;
    }
    bool guided = guide.pattern.breath > 0;
    (int, BreathPhase) phase = (state.breath, state.phase);
    bool newPhase = guided && phase != _lastPhase;
    if (newPhase) {
      _lastPhase = phase;
      if (state.intoPhase <= _cueLateLimit) {
        _cue(state.phase);
      }
    }
    int phaseLeft = (state.phaseLeft.inMilliseconds / 1000).ceil();
    if (newPhase ||
        phaseLeft != _phaseLeft ||
        state.breaths != _breaths ||
        state.remaining.inSeconds != _remaining.inSeconds) {
      setState(() {
        _remaining = state.remaining;
        _breaths = state.breaths;
        _phaseLeft = phaseLeft;
        if (newPhase) {
          _phase = state.phase;
          _status = _phaseText(state.phase);
        }
      });
    }
  }

  /// Every frame: the circle's size, the dot on the wave and the progress.
  void _updateCircle() {
    Session? session = _session;
    BreathingSession? guide = _guide;
    if (session == null || guide == null) return;
    if (_paused) return;
    Duration elapsed = _elapsed();
    BreathingState state = guide.stateAt(elapsed);
    _scale.value = state.scale;
    _cycle.value = state.cycleProgress;
    int total = guide.length.inMilliseconds;
    _progress.value = total > 0
        ? (elapsed.inMilliseconds / total).clamp(0.0, 1.0)
        : 0.0;
  }

  void _end(DateTime end, int breaths) {
    Session? session = _session;
    if (session == null) return;
    _session = null;
    _guide = null;
    _timer?.cancel();
    _timer = null;
    _ticker.stop();
    _wakeLock(false);
    AndroidSystem.stopSession();

    _paused = false;
    _pausedAt = null;
    session.end = end.isBefore(session.start) ? session.start : end;
    session.breaths = breaths;
    if (_preferenceName != APP_NAME) {
      session.description = _preferenceName;
    }
    _scale.value = 0.0;
    _cycle.value = 0.0;
    _progress.value = 0.0;
    setState(() {
      _phase = BreathPhase.inhale;
      _phaseLeft = 0;
      _status = AppLocalizations.of(context).pressStart;
      _isRunning = false;
      _breaths = 0;
      _update();
    });
    _finish(session);
  }

  /// A small pill in [color] (the seconds left of the current part).
  Widget _pill(Color color, String text) {
    return Container(
      constraints: const BoxConstraints(minWidth: 34.0),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: tintColor(context, color, 0.3),
        borderRadius: BorderRadius.circular(14.0),
        border: edgeBorder(context, color),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: tintTextColor(context, color),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// How far through the session, as a thin bar with edges.
  Widget _progressBar() {
    ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      height: 6.0,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(3.0),
        border: lineBorder(context),
      ),
      alignment: Alignment.centerLeft,
      child: ValueListenableBuilder<double>(
        valueListenable: _progress,
        builder: (context, progress, child) => FractionallySizedBox(
          widthFactor: progress,
          heightFactor: 1.0,
          child: child,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(3.0),
            border: edgeBorder(context, colors.primary),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    if (_status.isEmpty) {
      _status = l10n.pressStart;
    }
    Preference preference = _preference;
    BreathPattern pattern =
        _guide?.pattern ?? BreathPattern(preference.inhale, preference.exhale);
    double? perMinute = pattern.breathsPerMinute;
    Color color = phaseColor(_phase);

    return PopScope(
      // Going back while meditating stops (and saves) the session
      canPop: !_isRunning && !_finishing,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _isRunning) {
          _buttonPressed();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_preferenceName),
          // Shows which sensors are being measured during this session
          actions: [
            if (_recorder != null && widget.measureMotion)
              Tooltip(
                message: l10n.measureMotion,
                child: const Icon(Icons.sensors_rounded),
              ),
            if (_recorder != null && widget.measureSound)
              Tooltip(
                message: l10n.measureSound,
                child: const Icon(Icons.mic_rounded),
              ),
            const SizedBox(width: 16.0),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            // The circle shrinks a little on short screens
            double circle = (constraints.maxHeight * 0.26).clamp(110.0, 170.0);
            // Centered; scrolls only if it does not fit (very small screens
            // or large text)
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 88.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // What to do now, and the seconds left of it
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _ringVisible = !_ringVisible;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            key: Key(HomeWidget.keyStatusText),
                            _status,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w300,
                              color: _isRunning && !_paused
                                  ? tintTextColor(context, color)
                                  : null,
                            ),
                          ),
                          if (_isRunning && !_paused && _phaseLeft > 0) ...[
                            const SizedBox(width: 12.0),
                            _pill(color, "$_phaseLeft"),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // The breathing circle, in the color of the current part
                    SizedBox(
                      width: circle + 16.0,
                      height: circle + 16.0,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          // Outer ring (tap the text above to show it)
                          if (_ringVisible)
                            Container(
                              width: circle,
                              height: circle,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: lineColor(context),
                                  width: 4.0,
                                ),
                              ),
                            ),
                          TweenAnimationBuilder<Color?>(
                            tween: ColorTween(end: color),
                            duration: const Duration(milliseconds: 600),
                            builder: (context, value, child) {
                              Color fill = value ?? color;
                              // Only the circle redraws every frame
                              return ValueListenableBuilder<double>(
                                valueListenable: _scale,
                                builder: (context, scale, child) =>
                                    Transform.scale(
                                      scale: scale,
                                      child: Container(
                                        width: circle,
                                        height: circle,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: edgeBorder(context, fill),
                                          gradient: RadialGradient(
                                            colors: [
                                              fill.withValues(alpha: 0.55),
                                              fill,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: fill.withValues(
                                                alpha: 0.3,
                                              ),
                                              blurRadius: 24.0,
                                              spreadRadius: 2.0,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20.0),

                    // The breathing wave, with a dot where you are now
                    if (pattern.breath > 0)
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            14.0,
                            10.0,
                            14.0,
                            8.0,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(
                                    l10n.thisBreath,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const Spacer(),
                                  if (perMinute != null)
                                    Text(
                                      "${perMinute.toStringAsFixed(1)} "
                                      "${l10n.breathsUnit}${l10n.perMinute}",
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6.0),
                              BreathWave(
                                pattern: pattern,
                                progress: _cycle,
                                height: 84.0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 18.0),

                    // Time left, breaths, and the session's progress
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          getDurationString(_remaining),
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(width: 24.0),
                        Icon(
                          Icons.air_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          _breaths.toString(),
                          style: theme.textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    _progressBar(),
                  ],
                ),
              ),
            );
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        // Pause/Resume and Stop while meditating; Start before; a spinner
        // while the measurements are worked out
        floatingActionButton: _finishing
            ? FloatingActionButton.extended(
                heroTag: null,
                onPressed: null,
                tooltip: l10n.measuring,
                icon: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                label: Text(l10n.measuring),
              )
            : !_isRunning
            ? FloatingActionButton.extended(
                heroTag: null,
                onPressed: _buttonPressed,
                tooltip: l10n.start,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.start),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.extended(
                    key: const Key(HomeWidget.keyPause),
                    heroTag: null,
                    elevation: 0.0,
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    foregroundColor: theme.colorScheme.onSecondaryContainer,
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: edgeColor(
                          context,
                          theme.colorScheme.secondaryContainer,
                        ),
                        width: EDGE_WIDTH,
                      ),
                    ),
                    onPressed: _paused ? _resume : _pause,
                    tooltip: _paused ? l10n.resume : l10n.pause,
                    icon: Icon(
                      _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    ),
                    label: Text(_paused ? l10n.resume : l10n.pause),
                  ),
                  const SizedBox(width: 12.0),
                  FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: _buttonPressed,
                    tooltip: l10n.stop,
                    icon: const Icon(Icons.stop_rounded),
                    label: Text(l10n.stop),
                  ),
                ],
              ),
      ),
    );
  }
}
