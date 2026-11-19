// Schedules the daily meditation reminders as Android notifications.
//
// Reminders repeat daily at the chosen times. Whenever the settings or the
// sessions change (and when the app starts or comes back to the front),
// update() reschedules them: once today's goal is reached, they start again
// tomorrow. On days the app isn't opened, they simply keep coming.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_ce/hive.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:lucid/hive_storage.dart';
import 'package:lucid/reminder_settings.dart';

class Reminders {
  Reminders._();

  static const String
  _settingsKey = "reminders",
  _channelId = "reminders",
      // Notification icon: android/app/src/main/res/drawable-*/ic_notification.png
      _icon =
      "ic_notification";
  static const int _testId = 1000;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Reminders work on Android only.
  static bool get supported => !kIsWeb && Platform.isAndroid;

  static ReminderSettings load(Box settings) =>
      ReminderSettings.fromMap(settings.get(_settingsKey));

  static Future<void> save(Box settings, ReminderSettings reminders) =>
      settings.put(_settingsKey, reminders.toMap());

  static Future<bool> _init() async {
    if (!supported) return false;
    if (_ready) return true;
    tz_data.initializeTimeZones();
    try {
      TimezoneInfo timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (e) {
      debugPrint("reminders: time zone not found ($e), using UTC");
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_icon),
      ),
    );
    _ready = true;
    return true;
  }

  /// Asks for permission to show notifications (Android 13+). Returns false
  /// if it was refused.
  static Future<bool> requestPermission() async {
    if (!await _init()) return false;
    AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  static NotificationDetails _details(String channelName) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        channelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
  }

  /// Schedules the reminders from [settings], or cancels them if turned off.
  /// [title], [body] and [channelName] are the (translated) texts.
  static Future<void> update({
    required ReminderSettings settings,
    required Iterable<Session> sessions,
    required String title,
    required String body,
    required String channelName,
  }) async {
    try {
      if (!await _init()) return;
      await _plugin.cancelAll();
      if (!settings.enabled) return;

      DateTime now = DateTime.now();
      bool reached = goalReached(sessions, settings.goalMinutes, now);
      List<DateTime> dates = firstReminderDates(settings, reached, now);
      for (int i = 0; i < dates.length; i++) {
        DateTime date = dates[i];
        await _plugin.zonedSchedule(
          id: i,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime(
            tz.local,
            date.year,
            date.month,
            date.day,
            date.hour,
            date.minute,
          ),
          notificationDetails: _details(channelName),
          // Not to the minute (no special permission needed), which is fine
          // for a reminder
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          // Repeat every day at this time
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
      debugPrint("reminders: scheduled $dates");
    } catch (e) {
      debugPrint("reminders: $e");
    }
  }

  /// Shows a reminder right away, to check that notifications work.
  static Future<void> showTest({
    required String title,
    required String body,
    required String channelName,
  }) async {
    try {
      if (!await _init()) return;
      await _plugin.show(
        id: _testId,
        title: title,
        body: body,
        notificationDetails: _details(channelName),
      );
    } catch (e) {
      debugPrint("reminders: $e");
    }
  }
}
