// Breathing programs: ready-made patterns and your own, shown as colorful
// cards in Preferences. Choosing one sets the breathing pattern, the
// duration and the name; sounds, vibration and voice settings stay as they
// are. Your own programs are kept in the settings box (see MyPrograms).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

import 'package:lucid/breath_colors.dart';
import 'package:lucid/breath_wave.dart';
import 'package:lucid/breathing.dart';
import 'package:lucid/constants.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/theme.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

class Program {
  const Program({
    required this.key,
    required this.icon,
    required this.color,
    required this.inhale,
    required this.exhale,
    required this.duration,
    this.customName,
  });

  /// Identifies the program (also used as its key in tests).
  final String key;

  /// The name of one of your own programs (null for the built-in ones).
  final String? customName;
  bool get isCustom => customName != null;
  final IconData icon;
  final Color color;

  /// Lengths in milliseconds: [inhale, hold, second inhale] and
  /// [exhale, hold, second exhale].
  final List<int> inhale, exhale;

  /// Session length in seconds.
  final int duration;

  BreathPattern get pattern => BreathPattern(inhale, exhale);

  /// Whether [preference] breathes exactly like this program.
  bool matches(Preference preference) =>
      listEquals(preference.inhale, inhale) &&
      listEquals(preference.exhale, exhale);

  /// Same pattern, duration and name: the program [preference] was set from.
  bool isExactly(Preference preference) =>
      matches(preference) &&
      preference.duration == duration &&
      preference.name == customName;

  String name(AppLocalizations l10n) =>
      customName ??
      switch (key) {
        PRESET_478_TEXT => l10n.breathing478,
        BOX_TEXT => l10n.boxBreathing,
        PHYS_SIGH_TEXT => l10n.physiologicalSigh,
        COHERENT_TEXT => l10n.coherentBreathing,
        LONG_EXHALE_TEXT => l10n.longExhale,
        _ => l10n.equalBreathing,
      };

  String description(AppLocalizations l10n) => isCustom
      ? l10n.myProgramAbout
      : switch (key) {
          PRESET_478_TEXT => l10n.breathing478About,
          BOX_TEXT => l10n.boxBreathingAbout,
          PHYS_SIGH_TEXT => l10n.physiologicalSighAbout,
          COHERENT_TEXT => l10n.coherentBreathingAbout,
          LONG_EXHALE_TEXT => l10n.longExhaleAbout,
          _ => l10n.equalBreathingAbout,
        };
}

const List<Program> PROGRAMS = [
  Program(
    key: DEFAULT_TEXT,
    icon: Icons.drag_handle_rounded,
    color: INHALE_COLOR,
    inhale: [INHALE, INHALE_HOLD, INHALE_LAST],
    exhale: [EXHALE, EXHALE_HOLD, EXHALE_LAST],
    duration: DURATION,
  ),
  Program(
    key: BOX_TEXT,
    icon: Icons.crop_square_rounded,
    color: EXHALE_COLOR,
    inhale: [INHALE_BOX, INHALE_HOLD_BOX, 0],
    exhale: [EXHALE_BOX, EXHALE_HOLD_BOX, 0],
    duration: DURATION_BOX,
  ),
  Program(
    key: PRESET_478_TEXT,
    icon: Icons.change_history_rounded,
    color: HOLD_IN_COLOR,
    inhale: [INHALE_478, INHALE_HOLD_478, 0],
    exhale: [EXHALE_478, 0, 0],
    duration: DURATION_478,
  ),
  Program(
    key: PHYS_SIGH_TEXT,
    icon: Icons.keyboard_double_arrow_up_rounded,
    color: HOLD_OUT_COLOR,
    inhale: [INHALE_PS, INHALE_HOLD_PS, INHALE_LAST_PS],
    exhale: [EXHALE_PS, 0, 0],
    duration: DURATION_PS,
  ),
  Program(
    key: COHERENT_TEXT,
    icon: Icons.waves_rounded,
    color: Color(0xFF4FA3A5), // teal
    inhale: [5500, 0, 0],
    exhale: [5500, 0, 0],
    duration: 300,
  ),
  Program(
    key: LONG_EXHALE_TEXT,
    icon: Icons.south_east_rounded,
    color: Color(0xFF7E97B8), // soft blue-grey
    inhale: [4000, 0, 0],
    exhale: [6000, 0, 0],
    duration: 180,
  ),
];

/// The program [preference] was set from, if any: one of your own with the
/// same pattern, duration and name, or else a built-in one that breathes the
/// same way.
Program? programOf(Preference preference, [List<Program> mine = const []]) {
  for (Program program in mine) {
    if (program.isExactly(preference)) return program;
  }
  for (Program program in PROGRAMS) {
    if (program.matches(preference)) return program;
  }
  return null;
}

/// Your own programs, saved with "Save as program" (pattern, duration and
/// name), kept in the settings box.
class MyPrograms {
  MyPrograms._();

  static const String _settingsKey = "myPrograms";
  static const String keyPrefix = "custom-";

  // Colors and icon for your own cards, in turn
  static const List<Color> _colors = [
    EXHALE_COLOR,
    INHALE_COLOR,
    HOLD_OUT_COLOR,
    HOLD_IN_COLOR,
    Color(0xFF4FA3A5),
    Color(0xFF7E97B8),
  ];

  static List<Program> load(Box settings) {
    Object? stored = settings.get(_settingsKey);
    if (stored is! List) return [];
    List<Program> programs = [];
    for (Object? item in stored) {
      if (item is! Map) continue;
      try {
        programs.add(
          Program(
            key: "$keyPrefix${item['id']}",
            icon: Icons.bookmark_rounded,
            color: _colors[programs.length % _colors.length],
            inhale: List<int>.from(item['inhale'] as List),
            exhale: List<int>.from(item['exhale'] as List),
            duration: item['duration'] as int,
            customName: item['name'] as String? ?? "",
          ),
        );
      } catch (e) {
        debugPrint("program: $e");
      }
    }
    return programs;
  }

  static Future<void> _store(Box settings, List<Program> programs) =>
      settings.put(_settingsKey, [
        for (Program p in programs)
          {
            'id': p.key.substring(keyPrefix.length),
            'name': p.customName,
            'inhale': p.inhale,
            'exhale': p.exhale,
            'duration': p.duration,
          },
      ]);

  /// Saves a new program; returns it.
  static Future<Program> add(
    Box settings, {
    required String name,
    required List<int> inhale,
    required List<int> exhale,
    required int duration,
  }) async {
    List<Program> programs = load(settings);
    Program program = Program(
      key: "$keyPrefix${DateTime.now().microsecondsSinceEpoch}",
      icon: Icons.bookmark_rounded,
      color: _colors[programs.length % _colors.length],
      inhale: List.of(inhale),
      exhale: List.of(exhale),
      duration: duration,
      customName: name,
    );
    await _store(settings, [...programs, program]);
    return program;
  }

  static Future<void> remove(Box settings, String key) async {
    await _store(settings, [
      for (Program p in load(settings))
        if (p.key != key) p,
    ]);
  }

  static Future<void> clear(Box settings) => settings.delete(_settingsKey);
}

/// Once: the saved slots 1-5 of earlier versions (entries after the first in
/// the preferences box) become your own programs. Slots that were never
/// really used (unnamed defaults) or that equal a built-in program are left
/// out.
Future<void> moveSlotsToPrograms(Box preferences, Box settings) async {
  if (preferences.length <= 1) return;
  Preference defaults = Preference.getDefaultPref();
  List<Program> mine = MyPrograms.load(settings);
  for (int i = 1; i < preferences.length; i++) {
    Object? value = preferences.getAt(i);
    if (value is! Preference) continue;
    bool unused =
        value.name.isEmpty &&
        listEquals(value.inhale, defaults.inhale) &&
        listEquals(value.exhale, defaults.exhale) &&
        value.duration == defaults.duration;
    bool builtIn = PROGRAMS.any(
      (p) => p.matches(value) && p.duration == value.duration,
    );
    bool known = mine.any((p) => p.isExactly(value));
    if (unused || builtIn || known) continue;
    mine.add(
      await MyPrograms.add(
        settings,
        name: value.name.isEmpty ? "Saved $i" : value.name,
        inhale: value.inhale,
        exhale: value.exhale,
        duration: value.duration,
      ),
    );
  }
  while (preferences.length > 1) {
    await preferences.deleteAt(preferences.length - 1);
  }
}

/// Short duration, e.g. "1:16" or "5:00".
String shortDuration(int seconds) =>
    "${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}";

/// One part of a breath as a small colored pill, e.g. "4s".
class PhasePill extends StatelessWidget {
  const PhasePill({super.key, required this.phase, required this.ms});

  final BreathPhase phase;
  final int ms;

  @override
  Widget build(BuildContext context) {
    Color color = phaseColor(phase);
    Color fill = tintColor(context, color, 0.3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10.0),
        border: edgeBorder(context, color),
      ),
      child: Text(
        "${secondsText(ms)}s",
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tintTextColor(context, color),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Pills for each part of [pattern] that lasts longer than zero.
List<Widget> phasePills(BreathPattern pattern) => [
  for (BreathPhase phase in BreathPhase.values)
    if (pattern.lengthOf(phase) > 0)
      PhasePill(phase: phase, ms: pattern.lengthOf(phase)),
];

/// A program as a card: icon, name, its parts as pills, a small breathing
/// wave, and duration and pace. Tap to use it.
class ProgramCard extends StatelessWidget {
  const ProgramCard({
    super.key,
    required this.program,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final Program program;
  final bool selected;
  final VoidCallback onTap;

  /// For your own programs: long press to delete.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    Color color = program.color;
    Color text = tintTextColor(context, color);
    BreathPattern pattern = program.pattern;
    TextStyle? small = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Material(
      color: tintColor(context, color, selected ? 0.28 : 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18.0),
        side: selected
            ? BorderSide(color: color, width: 1.6)
            : BorderSide(color: edgeColor(context, color), width: EDGE_WIDTH),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key(program.key),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34.0,
                    height: 34.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tintColor(context, color, 0.4),
                      border: edgeBorder(context, color),
                    ),
                    child: Icon(program.icon, size: 19.0, color: text),
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(Icons.check_circle_rounded, size: 20.0, color: text),
                ],
              ),
              const SizedBox(height: 8.0),
              Text(
                program.name(l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6.0),
              Wrap(
                spacing: 4.0,
                runSpacing: 4.0,
                children: phasePills(pattern),
              ),
              const Spacer(),
              BreathWave(
                pattern: pattern,
                height: 30.0,
                showTicks: false,
                strokeWidth: 1.6,
              ),
              const SizedBox(height: 6.0),
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 13.0, color: small?.color),
                  const SizedBox(width: 3.0),
                  Text(shortDuration(program.duration), style: small),
                  const Spacer(),
                  Text(
                    "${pattern.breathsPerMinute?.toStringAsFixed(1)} ${l10n.perMinute}",
                    style: small,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
