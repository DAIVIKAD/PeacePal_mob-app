// lib/src/services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // MUST be called once in main()
  static Future<void> init() async {
    if (_initialized) return;

    // Timezone setup
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint("Notification tapped: ${response.payload}");
      },
    );

    // Notification channel (Android 8+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'peacepal_reminders',
      'PeacePal Reminders',
      description: 'Medication & wellness reminders',
      importance: Importance.max,
    );

    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(channel);
      await androidImpl.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Simple test notification button (you already saw this works)
  static Future<void> showTest() async {
    await init();

    const android = AndroidNotificationDetails(
      'peacepal_reminders',
      'PeacePal Reminders',
      channelDescription: 'Medication & wellness reminders',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(
      android: android,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      9999,
      "PeacePal Test",
      "Local notifications are working! 🎉",
      details,
    );
  }

  /// 1) PINNED / ONGOING notification shown immediately when user taps "Save"
  static Future<void> showPinnedSetupNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();

    const android = AndroidNotificationDetails(
      'peacepal_reminders',
      'PeacePal Reminders',
      channelDescription: 'Medication & wellness reminders',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true, // 🔒 pinned
      autoCancel: false,
    );

    const details = NotificationDetails(
      android: android,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      id,
      title,
      body,
      details,
      payload: 'pinned_setup',
    );
  }

  /// 2) REAL scheduled reminder (same ID as pinned one)
  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    await init();

    final now = DateTime.now();
    var scheduleTime = scheduledAt;

    // Safety: if somehow past -> fire in 10s
    if (scheduleTime.isBefore(now)) {
      scheduleTime = now.add(const Duration(seconds: 10));
    }

    final tzTime = tz.TZDateTime.from(scheduleTime, tz.local);

    debugPrint('Scheduling notif id=$id at $tzTime');

    const android = AndroidNotificationDetails(
      'peacepal_reminders',
      'PeacePal Reminders',
      channelDescription: 'Medication & wellness reminders',
      importance: Importance.max,
      priority: Priority.high,
      // 🔓 this one is NOT ongoing, so user can dismiss when triggered
      ongoing: false,
      autoCancel: true,
    );

    const details = NotificationDetails(
      android: android,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      details,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'scheduled_reminder',
    );
  }

  /// Optional helper if later you want to cancel a specific reminder by id
  static Future<void> cancelById(int id) async {
    await _plugin.cancel(id);
  }

  /// Optional helper to nuke everything
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
