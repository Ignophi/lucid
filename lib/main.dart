import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'package:lucid/app_shell.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/home_widget.dart';
import 'package:lucid/programs.dart';
import 'package:lucid/constants.dart';
import 'package:lucid/utils.dart';
import 'package:lucid/theme.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

Future<void> main() async {
  // Do not debugPrint in release
  bool isInRelease = true;
  assert(() {
    isInRelease = false;
    return true;
  }());
  if (isInRelease) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Initialize Hive
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(PreferenceAdapter());
  Hive.registerAdapter(SessionAdapter());

  // Initialize package info
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  String appName = packageInfo.appName;
  String version = "${packageInfo.version}+${packageInfo.buildNumber}";
  String major = packageInfo.version.split(".")[0];
  String minor = packageInfo.version.split(".")[1];

  // Initialize Hive boxes
  Box preferences;
  String preferencesBox = "preferences.$major.$minor";
  try {
    preferences = await Hive.openBox(preferencesBox);
  } catch (e) {
    // Corrupted or incompatible box
    debugPrint(e.toString());
    await Hive.deleteBoxFromDisk(preferencesBox);
    // Try again
    preferences = await Hive.openBox(preferencesBox);
  }

  Box sessions;
  const String SESSIONS_BOX = "sessions";
  try {
    sessions = await Hive.openBox(SESSIONS_BOX);
  } catch (e) {
    // Corrupted or incompatible box
    debugPrint(e.toString());
    await Hive.deleteBoxFromDisk(SESSIONS_BOX);
    // Try again
    sessions = await Hive.openBox(SESSIONS_BOX);
  }

  Box settings;
  const String SETTINGS_BOX = "settings";
  try {
    settings = await Hive.openBox(SETTINGS_BOX);
  } catch (e) {
    // Corrupted or incompatible box
    debugPrint(e.toString());
    await Hive.deleteBoxFromDisk(SETTINGS_BOX);
    // Try again
    settings = await Hive.openBox(SETTINGS_BOX);
  }

  if (preferences.isEmpty) {
    await createDefaultPref(preferences);
  }

  // Session types were simplified (e.g. "Sitting breathing" is now "Sitting")
  try {
    await updateSessionTypes(sessions);
  } catch (e) {
    debugPrint(e.toString());
  }

  // Hold sounds are silent now; your own saved slots became programs
  try {
    await silenceHoldSounds(preferences, settings);
    await moveSlotsToPrograms(preferences, settings);
  } catch (e) {
    debugPrint(e.toString());
  }

  // Demo data for screenshots and tests only. Run with
  // flutter run --dart-define=DEMO_SESSIONS=true
  // to fill the app with random sessions (this rewrites the sessions box).
  if (kDebugMode && const bool.fromEnvironment('DEMO_SESSIONS')) {
    await createRandomSessions(
      sessions,
      HomeWidget.totalSessions,
      DateTime.now().subtract(const Duration(days: 180)),
      DateTime.now().subtract(const Duration(days: 1)),
    );
  }

  runApp(
    MainWidget(
      appName: appName,
      version: version,
      preferences: preferences,
      sessions: sessions,
      settings: settings,
    ),
  );
}

class MainWidget extends StatelessWidget {
  const MainWidget({
    super.key,
    required this.appName,
    required this.version,
    required this.preferences,
    required this.sessions,
    required this.settings,
  });

  final String appName, version;
  final Box preferences, sessions, settings;

  @override
  Widget build(BuildContext context) {
    Color seedColor = APP_ACCENT;
    Color? backgroundColor;
    if (preferences.isNotEmpty) {
      Preference preference = preferences.getAt(0);
      int colorIndex = preference.colors[0];
      // The default color slot uses the app's accent; others keep their color
      if (colorIndex != COLOR_PRIMARY &&
          colorIndex >= 0 &&
          colorIndex < COLORS_PRIMARY.length) {
        seedColor = COLORS_PRIMARY[colorIndex];
      }
      // Only override the theme's background if a custom one was chosen
      if (preference.colors[1] != COLOR_BACKGROUND) {
        backgroundColor = Color(preference.colors[1]);
      }
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(
        seedColor,
        Brightness.light,
        backgroundColor: backgroundColor,
      ),
      darkTheme: buildTheme(seedColor, Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppShell(
        appName: appName,
        version: version,
        preferences: preferences,
        sessions: sessions,
        settings: settings,
      ),
    );
  }
}
