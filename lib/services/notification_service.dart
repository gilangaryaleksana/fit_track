import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;
import '../db/database_helper.dart';
import 'settings_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static const int _dailyReminderId = 1;
  static const int _goalAchievedId = 2;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    timezone_data.initializeTimeZones();
    timezone.setLocalLocation(timezone.getLocation('Asia/Jakarta'));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);
    await _scheduleDailyReminder();
  }

  Future<void> updateDailyReminder() => _scheduleDailyReminder();

  Future<void> _scheduleDailyReminder() async {
    final settings = SettingsService.instance;
    await settings.initialize();
    if (!settings.dailyReminderEnabled) {
      await _plugin.cancel(_dailyReminderId);
      return;
    }

    final now = timezone.TZDateTime.now(timezone.local);
    var scheduled = timezone.TZDateTime(
      timezone.local,
      now.year,
      now.month,
      now.day,
      settings.reminderHour,
      settings.reminderMinute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Waktunya bergerak!',
      'Yuk, luangkan waktu untuk berolahraga hari ini.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'fittrack_reminders',
          'Pengingat olahraga',
          channelDescription: 'Pengingat harian untuk berolahraga',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> checkGoalAchievement(int userId) async {
    if (!SettingsService.instance.goalNotificationEnabled) return;
    final now = DateTime.now();
    final target = await DatabaseHelper.instance.getTargetByDate(userId, now);
    if (target == null) return;
    final activities =
        await DatabaseHelper.instance.getActivitiesByDate(userId, now);
    final calories = activities.fold<double>(
        0, (total, activity) => total + activity.caloriesBurned);
    final minutes = activities.fold<int>(
        0, (total, activity) => total + activity.durationMinutes);
    if (calories < target.targetCalories ||
        minutes < target.targetDurationMinutes) {
      return;
    }

    final dateKey = '${now.year}-${now.month}-${now.day}';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('settings.lastGoalNotificationDate') == dateKey) return;
    await showGoalAchieved();
    await prefs.setString('settings.lastGoalNotificationDate', dateKey);
  }

  Future<void> showGoalAchieved() async {
    if (!SettingsService.instance.goalNotificationEnabled) return;
    await _plugin.show(
      _goalAchievedId,
      'Target tercapai!',
      'Hebat! Target harianmu sudah tercapai.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'fittrack_goals',
          'Target tercapai',
          channelDescription: 'Pemberitahuan saat target harian tercapai',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
