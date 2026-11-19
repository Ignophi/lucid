// Which sensors are recorded during sessions. Motion is on by default; the
// microphone is off until the user turns it on.

import 'package:hive_ce/hive.dart';

class MeasureSettings {
  MeasureSettings({this.motion = true, this.sound = false});

  bool motion, sound;

  static const String _settingsKey = "measurements";

  static MeasureSettings load(Box settings) {
    Object? map = settings.get(_settingsKey);
    MeasureSettings result = MeasureSettings();
    if (map is Map) {
      result.motion = map['motion'] != false;
      result.sound = map['sound'] == true;
    }
    return result;
  }

  Future<void> save(Box settings) =>
      settings.put(_settingsKey, {'motion': motion, 'sound': sound});
}
