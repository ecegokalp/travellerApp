import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(settings);
    _initialized = true;

    // Request notification permission on Android 13+
    _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Schedule a notification at a specific date/time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_initialized) await init();

    // Don't schedule notifications in the past
    if (scheduledDate.isBefore(DateTime.now())) return;

    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'travel_reminders',
      'Travel Reminders',
      channelDescription: 'Reminders for upcoming travel events',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );

    debugPrint('Notification scheduled: "$title" at $scheduledDate');
  }

  /// Schedule reminders for a calendar event (1 day before + 3 hours before)
  Future<void> scheduleEventReminders({
    required String eventId,
    required String eventName,
    required String eventType,
    required DateTime eventDate,
    String? city,
  }) async {
    final baseId = eventId.hashCode.abs() % 100000;
    final location = city != null ? ' in $city' : '';

    // 1 day before
    final oneDayBefore = eventDate.subtract(const Duration(days: 1));
    await scheduleNotification(
      id: baseId,
      title: 'Tomorrow: $eventName',
      body: 'Your $eventType$location is tomorrow! Make sure everything is ready.',
      scheduledDate: oneDayBefore,
    );

    // 3 hours before
    final threeHoursBefore = eventDate.subtract(const Duration(hours: 3));
    await scheduleNotification(
      id: baseId + 1,
      title: 'Coming up: $eventName',
      body: 'Your $eventType$location is in 3 hours!',
      scheduledDate: threeHoursBefore,
    );
  }

  /// Cancel notifications for an event
  Future<void> cancelEventReminders(String eventId) async {
    final baseId = eventId.hashCode.abs() % 100000;
    await _plugin.cancel(baseId);
    await _plugin.cancel(baseId + 1);
  }
}
