import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class AlarmService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    
    await _notifications.initialize(settings);
    
    // Request permissions for Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Schedule meal reminders
  static Future<void> scheduleMealReminders({
    required String breakfastTime,
    required String lunchTime,
    required String dinnerTime,
  }) async {
    await _cancelAllReminders();
    
    // Schedule breakfast reminder
    await _scheduleRepeatingNotification(
      id: 1,
      title: '🍳 Breakfast Time!',
      body: 'Time for your healthy breakfast according to your meal plan',
      time: breakfastTime,
    );
    
    // Schedule lunch reminder
    await _scheduleRepeatingNotification(
      id: 2,
      title: '🥗 Lunch Time!',
      body: 'Don\'t forget your nutritious lunch',
      time: lunchTime,
    );
    
    // Schedule dinner reminder
    await _scheduleRepeatingNotification(
      id: 3,
      title: '🍽️ Dinner Time!',
      body: 'Time for your evening meal',
      time: dinnerTime,
    );

    // Save reminder times
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('breakfast_time', breakfastTime);
    await prefs.setString('lunch_time', lunchTime);
    await prefs.setString('dinner_time', dinnerTime);
    await prefs.setBool('reminders_enabled', true);
  }

  static Future<void> _scheduleRepeatingNotification({
    required int id,
    required String title,
    required String body,
    required String time,
  }) async {
    try {
      final timeParts = time.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      print('Scheduling notification for $title at $scheduledDate');

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'meal_reminders',
            'Meal Reminders',
            channelDescription: 'Notifications for meal times',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
            autoCancel: false,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      
      print('Notification scheduled successfully for $title');
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  static Future<void> _cancelAllReminders() async {
    await _notifications.cancelAll();
  }

  static Future<void> disableReminders() async {
    await _cancelAllReminders();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminders_enabled', false);
    await prefs.remove('breakfast_time');
    await prefs.remove('lunch_time');
    await prefs.remove('dinner_time');
  }

  static Future<bool> areRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('reminders_enabled') ?? false;
  }

  static Future<Map<String, String>> getSavedTimes() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'breakfast': prefs.getString('breakfast_time') ?? '08:00',
      'lunch': prefs.getString('lunch_time') ?? '13:00',
      'dinner': prefs.getString('dinner_time') ?? '19:00',
    };
  }
}