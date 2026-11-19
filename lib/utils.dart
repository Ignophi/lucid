import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:lucid/constants.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

/// Display name for a session type key (see SESSION_TYPES in constants.dart).
/// Unknown keys are shown as-is, so nothing is lost if a key isn't listed.
String sessionTypeLabel(BuildContext context, String type) {
  AppLocalizations l10n = AppLocalizations.of(context);
  switch (type) {
    case SESSION_TYPE_SITTING:
      return l10n.sessionTypeSitting;
    case SESSION_TYPE_LYING:
      return l10n.sessionTypeLying;
    case SESSION_TYPE_WALKING:
      return l10n.sessionTypeWalking;
    case SESSION_TYPE_BODY_SCAN:
      return l10n.sessionTypeBodyScan;
    case SESSION_TYPE_OTHER:
      return l10n.sessionTypeOther;
    default:
      return type;
  }
}

/// Icon for a session type key; a generic icon when no type is set.
IconData sessionTypeIcon(String? type) {
  switch (type) {
    case SESSION_TYPE_SITTING:
      return Icons.self_improvement;
    case SESSION_TYPE_LYING:
      return Icons.airline_seat_flat;
    case SESSION_TYPE_WALKING:
      return Icons.directions_walk;
    case SESSION_TYPE_BODY_SCAN:
      return Icons.accessibility_new;
    case null:
    case "":
      return Icons.category_outlined;
    default:
      return Icons.more_horiz_rounded;
  }
}

// Used for testing
Future<void> createRandomSessions(
  Box sessions,
  int length,
  DateTime start,
  DateTime end,
) async {
  Random random = Random(DateTime.now().millisecondsSinceEpoch);
  DateTime mockStart, mockEnd;
  Session session;
  List<Session> list = sessions.values.toList().cast<Session>();

  while (list.length < length - 1) {
    mockStart = _mockDate(start, end);
    mockEnd = _mockDate(
      mockStart,
      mockStart.add(Duration(seconds: random.nextInt(120 * 60))),
    );
    session = Session(start: mockStart);
    session.end = mockEnd;
    int breaths =
        (mockEnd.millisecondsSinceEpoch - mockStart.millisecondsSinceEpoch) ~/
        Duration.millisecondsPerSecond;
    session.breaths = breaths ~/ (random.nextInt(10) + 1);
    list.add(session);
  }

  // Add heartrate session
  if (list.length < length) {
    session = Session(
      start: DateTime.now().subtract(const Duration(minutes: 60)),
    );
    session.end = session.start.add(const Duration(seconds: 60));
    session.breaths = 10;
    session.heartrates = [70, 69, 68, 67, 66, 65, 64, 63, 62, 61, 60];
    list.add(session);
  }

  list.sort(
    (a, b) => a.start.millisecondsSinceEpoch.compareTo(
      b.start.millisecondsSinceEpoch,
    ),
  );
  await sessions.clear();
  await sessions.addAll(list);

  debugPrint("sessions: ${sessions.values}");
}

DateTime _mockDate([DateTime? firstMoment, DateTime? secondMoment]) {
  Random random = Random(); //Random(DateTime.now().millisecondsSinceEpoch);
  firstMoment ??= DateTime.fromMillisecondsSinceEpoch(0);
  secondMoment ??= DateTime.now();
  Duration difference = secondMoment.difference(firstMoment);
  return firstMoment.add(
    Duration(seconds: random.nextInt(difference.inSeconds + 1)),
  );
}

/// Converts session types saved by earlier versions to the current ones
/// (e.g. "Sitting breathing" became "Sitting"). Returns how many changed.
Future<int> updateSessionTypes(Box sessions) async {
  Map<dynamic, Session> changed = {};
  for (dynamic key in sessions.keys) {
    dynamic session = sessions.get(key);
    if (session is Session) {
      String? type = currentSessionType(session.sessionType);
      if (type != session.sessionType) {
        session.sessionType = type;
        changed[key] = session;
      }
    }
  }
  if (changed.isNotEmpty) {
    await sessions.putAll(changed);
    debugPrint("updated session types: ${changed.length}");
  }
  return changed.length;
}

/// Once: the hold sounds became silent by default, so settings still using
/// the old hold tones (Tone 3 and Tone 4) are switched to none.
Future<void> silenceHoldSounds(Box preferences, Box settings) async {
  const String done = "holdSoundsSilenced";
  if (settings.get(done) == true) return;
  for (dynamic value in preferences.values) {
    if (value is Preference && value.audio.length >= 4) {
      bool changed = false;
      if (value.audio[2] == AUDIO_TONE3) {
        value.audio[2] = AUDIO_NONE;
        changed = true;
      }
      if (value.audio[3] == AUDIO_TONE4) {
        value.audio[3] = AUDIO_NONE;
        changed = true;
      }
      if (changed) await value.save();
    }
  }
  await settings.put(done, true);
}

Future<void> createDefaultPref(Box preferences) async {
  Preference preference = Preference.getDefaultPref();
  await preferences.add(preference);

  debugPrint("created default preference: $preference");
}

void showAlertDialog(
  BuildContext context,
  String title,
  String content,
  callback,
) {
  Widget cancelButton = TextButton(
    child: Text(
      AppLocalizations.of(context).cancel,
      key: const Key(CANCEL_TEXT),
    ),
    onPressed: () {
      Navigator.of(context).pop();
    },
  );
  Widget continueButton = TextButton(
    key: const Key(CONTINUE_TEXT),
    onPressed: callback,
    child: Text(AppLocalizations.of(context).cont),
  );

  AlertDialog alert = AlertDialog(
    title: Text(title),
    content: Text(content),
    actions: [cancelButton, continueButton],
  );

  // show the dialog
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}

Future<void> play(AudioPlayer player, String audio) async {
  if (audio == AUDIO_TONE1) {
    await player.play(AssetSource('tone1.oga'));
  } else if (audio == AUDIO_TONE2) {
    await player.play(AssetSource('tone2.oga'));
  } else if (audio == AUDIO_TONE3) {
    await player.play(AssetSource('tone3.oga'));
  } else if (audio == AUDIO_TONE4) {
    await player.play(AssetSource('tone4.oga'));
  }
}

bool isWeb() {
  return kIsWeb;
}
