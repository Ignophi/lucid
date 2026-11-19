import 'package:flutter/material.dart';

const String APP_NAME = "Lucid",
        // Change if your repository has another name
        REPO_URL =
        "https://github.com/Ignophi/lucid",
    BUGS_URL = "$REPO_URL/issues",
    LICENSE_TEXT = "Free software under the GNU General Public License v3.";

// Lucid is a modified version of Brethap (GPL-3.0): keep the credit in About
const String BASED_ON_TEXT = "Based on Brethap by Jithware",
    BASED_ON_URL = "https://github.com/jithware/brethap";

const String DATE_FORMAT = "yyyy-MM-dd h:mm a",
    PRESS_BUTTON_TEXT = "Press Start",
    INHALE_TEXT = "Inhale",
    EXHALE_TEXT = "Exhale",
    HOLD_TEXT = "Hold",
    INHALE_HOLD_TEXT = "Inhale Hold",
    EXHALE_HOLD_TEXT = "Exhale Hold",
    INHALE_LAST_TEXT = "Inhale Last",
    EXHALE_LAST_TEXT = "Exhale Last",
    INHALE_AUDIO_TEXT = "Inhale Audio",
    INHALE_HOLD_AUDIO_TEXT = "Inhale Hold Audio",
    EXHALE_AUDIO_TEXT = "Exhale Audio",
    EXHALE_HOLD_AUDIO_TEXT = "Exhale Hold Audio",
    DURATION_TEXT = "Duration",
    DURATION_MINUTES_TEXT = "Duration Minutes",
    DURATION_SECONDS_TEXT = "Duration Seconds",
    DURATION_VIBRATE_TEXT = "Duration Vibrate",
    DURATION_TTS_TEXT = "Duration TTS",
    BREATH_VIBRATE_TEXT = "Breath Vibrate",
    BREATH_TTS_TEXT = "Breath TTS",
    CLEAR_ALL_TEXT = "Clear All",
    RESET_ALL_TEXT = "Reset All",
    BACKUP_TEXT = "Backup",
    RESTORE_TEXT = "Restore",
    EXPORT_TEXT = "Export",
    IMPORT_TEXT = "Import",
    PRESETS_TEXT = "Presets",
    DISMISS_TEXT = "Dismiss",
    DEFAULT_TEXT = "Default",
    PHYS_SIGH_TEXT = "Physiological Sigh",
    PRESET_478_TEXT = "4-7-8 Breathing",
    BOX_TEXT = "Box Breathing",
    COHERENT_TEXT = "Coherent Breathing",
    LONG_EXHALE_TEXT = "Long Exhale",
    CONTINUE_TEXT = "Continue",
    CANCEL_TEXT = "Cancel",
    OK_TEXT = "Ok",
    COLOR_PRIMARY_TEXT = "Primary Color",
    COLOR_BACKGROUND_TEXT = "Background Color",
    NAME_TEXT = "Name",
    AUDIO_NONE = "None",
    AUDIO_TONE1 = "Tone 1",
    AUDIO_TONE2 = "Tone 2",
    AUDIO_TONE3 = "Tone 3",
    AUDIO_TONE4 = "Tone 4";

// Session types: how you meditated (the posture, or a body scan). These keys
// are what gets saved with each session, so keep existing keys unchanged; the
// label shown for each key comes from sessionTypeLabel() in utils.dart. To
// add a type, add a key here and a label there (plus a string in
// lib/l10n/app_en.arb).
const String SESSION_TYPE_SITTING = "sitting",
    SESSION_TYPE_LYING = "lying",
    SESSION_TYPE_WALKING = "walking",
    SESSION_TYPE_BODY_SCAN = "body_scan",
    SESSION_TYPE_OTHER = "other";

const List<String> SESSION_TYPES = [
  SESSION_TYPE_SITTING,
  SESSION_TYPE_LYING,
  SESSION_TYPE_WALKING,
  SESSION_TYPE_BODY_SCAN,
  SESSION_TYPE_OTHER,
];

/// Types used by earlier versions and the type each became. Sessions saved
/// or exported with them are converted when read.
const Map<String, String> SESSION_TYPES_RENAMED = {
  "sitting_meditation": SESSION_TYPE_SITTING,
  "sitting_breathing": SESSION_TYPE_SITTING,
  "lying_breathing": SESSION_TYPE_LYING,
  "walking_meditation": SESSION_TYPE_WALKING,
  "walking_breathing": SESSION_TYPE_WALKING,
};

/// [type] under its current key (older keys are converted).
String? currentSessionType(String? type) => SESSION_TYPES_RENAMED[type] ?? type;

const int RATING_MIN = 0, RATING_MAX = 100, COMMENT_MAX_LENGTH = 500;

// Default values
const int DURATION = 120, //seconds
INHALE = 4000, //milliseconds
INHALE_HOLD = 0, //milliseconds
INHALE_LAST = 0, //milliseconds
EXHALE = 4000, //milliseconds
EXHALE_HOLD = 0, //milliseconds
EXHALE_LAST = 0, //milliseconds
VIBRATE_DURATION = 250, //milliseconds
VIBRATE_BREATH = 50, //milliseconds
COLOR_PRIMARY = 0, //color position
COLOR_BACKGROUND = 0xfffafafa; //color white
const bool DURATION_TTS = false, BREATH_TTS = false;
const String INHALE_AUDIO = AUDIO_TONE1,
    EXHALE_AUDIO = AUDIO_TONE2,
        // Holds are silent by default
        INHALE_HOLD_AUDIO =
        AUDIO_NONE,
    EXHALE_HOLD_AUDIO = AUDIO_NONE;

const List<ColorSwatch> COLORS_PRIMARY = <ColorSwatch>[
  Colors.blue,
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.deepPurple,
  Colors.indigo,
  Colors.lightBlue,
  Colors.cyan,
  Colors.teal,
  Colors.green,
  Colors.lightGreen,
  Colors.lime,
  Colors.yellow,
  Colors.amber,
  Colors.orange,
  Colors.deepOrange,
  Colors.brown,
  Colors.grey,
  Colors.blueGrey,
];

const List<ColorSwatch> COLORS_BACKGROUND = COLORS_PRIMARY;

// Physiological sigh values
const int DURATION_PS =
        15, //seconds
    INHALE_PS =
        1000, //milliseconds
    INHALE_HOLD_PS =
        500, //milliseconds
    INHALE_LAST_PS =
        500, //milliseconds
    EXHALE_PS = 3000; //milliseconds

// 4-7-8 values
const int DURATION_478 =
        76, //seconds
    INHALE_478 =
        4000, //milliseconds
    INHALE_HOLD_478 =
        7000, //milliseconds
    EXHALE_478 = 8000; //milliseconds

// Box values
const int DURATION_BOX =
        60, //seconds
    INHALE_BOX =
        4000, //milliseconds
    INHALE_HOLD_BOX =
        4000, //milliseconds
    EXHALE_BOX =
        4000, //milliseconds
    EXHALE_HOLD_BOX = 4000; //milliseconds
