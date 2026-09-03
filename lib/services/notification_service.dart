import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Notification Channel Constants
  static const String channelId = 'fitloop_reminders';
  static const String channelName = 'FitLoop Reminders';
  static const String channelDescription =
      'Scheduled reminders for workouts, meals, hydration, and weekly progress.';

  // Deterministic Notification ID ranges
  static const int workoutIdBase = 1000; // 1001-1007 (weekday 1..7)
  static const int mealBreakfastId = 2001;
  static const int mealLunchId = 2002;
  static const int mealDinnerId = 2003;
  static const int hydrationIdBase = 3000; // 3001-3010
  static const int weeklyProgressId = 4001;
  static const int diagnosticTestId = 9999;
  static const int diagnosticScheduledId = 9998;

  @visibleForTesting
  void setPluginForTesting(FlutterLocalNotificationsPlugin plugin) {
    _notificationsPlugin = plugin;
    _isInitialized = true;
  }

  /// Initializes timezone data and notification plugin.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      
      // Resolve device physical timezone
      try {
        if (!kIsWeb) {
          final TimezoneInfo tzInfo = await FlutterTimezone.getLocalTimezone();
          final String currentTimeZone = tzInfo.identifier;
          debugPrint('Device local timezone detected: $currentTimeZone');
          if (tz.timeZoneDatabase.locations.containsKey(currentTimeZone)) {
            tz.setLocalLocation(tz.getLocation(currentTimeZone));
          } else {
            debugPrint('Timezone $currentTimeZone not found in database, searching by offset...');
            _fallbackTimezoneResolution();
          }
        }
      } catch (e) {
        debugPrint('Could not get device timezone via FlutterTimezone: $e');
        _fallbackTimezoneResolution();
      }

      debugPrint('NotificationService initialized with timezone: ${tz.local.name} (Offset: ${tz.local.currentTimeZone.offset ~/ 3600000}h)');

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification tapped with payload: ${response.payload}');
        },
      );

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully.');

      // Check permission status at startup
      final hasPermission = await areNotificationsGranted();
      debugPrint('Notification permission granted: $hasPermission');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  void _fallbackTimezoneResolution() {
    try {
      final offset = DateTime.now().timeZoneOffset;
      final location = tz.timeZoneDatabase.locations.values.firstWhere(
        (l) => l.currentTimeZone.offset == offset,
        orElse: () => tz.getLocation('UTC'),
      );
      tz.setLocalLocation(location);
      debugPrint('Fallback timezone set to: ${location.name}');
    } catch (_) {}
  }

  /// Request runtime permissions safely across Android and iOS platforms.
  Future<bool> requestPermissions() async {
    try {
      if (kIsWeb) return false;

      if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          final granted = await androidImpl.requestNotificationsPermission();
          return granted ?? false;
        }
      } else if (Platform.isIOS) {
        final iosImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        if (iosImpl != null) {
          final granted = await iosImpl.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          return granted ?? false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Check if notification permissions are granted.
  Future<bool> areNotificationsGranted() async {
    try {
      if (kIsWeb) return false;

      if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          final areEnabled = await androidImpl.areNotificationsEnabled();
          return areEnabled ?? false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error checking notification permission status: $e');
      return false;
    }
  }

  NotificationDetails _notificationDetails() {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      category: AndroidNotificationCategory.reminder,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  /// Determines the safest Android schedule mode available.
  /// Uses exact alarms if the system grants permission, otherwise gracefully falls back to inexact.
  Future<AndroidScheduleMode> _getSafeScheduleMode() async {
    try {
      if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          final canExact = await androidImpl.canScheduleExactNotifications();
          debugPrint('Android canScheduleExactNotifications: $canExact');
          if (canExact == true) {
            return AndroidScheduleMode.exactAllowWhileIdle;
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking exact alarm permissions: $e');
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Displays an immediate test notification for permission, channel, and icon verification.
  Future<void> sendImmediateTestNotification({
    String title = 'FitLoop Test Notification 🔔',
    String body = 'Notifications are working properly on your device!',
  }) async {
    try {
      await _notificationsPlugin.show(
        id: diagnosticTestId,
        title: title,
        body: body,
        notificationDetails: _notificationDetails(),
        payload: 'route:/test_immediate',
      );
      debugPrint('Immediate test notification displayed successfully (ID $diagnosticTestId).');
    } catch (e) {
      debugPrint('Failed to display immediate notification: $e');
    }
  }

  /// Schedules a one-off diagnostic test notification (e.g. 60 seconds from now).
  Future<void> scheduleTestNotification({int secondsFromNow = 60}) async {
    try {
      final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(seconds: secondsFromNow));
      final scheduleMode = await _getSafeScheduleMode();

      debugPrint('--- Diagnostic Schedule Test ---');
      debugPrint('Device local DateTime: ${DateTime.now()}');
      debugPrint('Timezone location: ${tz.local.name}');
      debugPrint('Current TZDateTime: ${tz.TZDateTime.now(tz.local)}');
      debugPrint('Scheduled TZDateTime: $scheduledDate (in $secondsFromNow seconds)');
      debugPrint('Android schedule mode: $scheduleMode');
      debugPrint('--------------------------------');

      await _notificationsPlugin.zonedSchedule(
        id: diagnosticScheduledId,
        title: 'FitLoop Scheduled Test ⏱️',
        body: 'Scheduled alarm fired successfully at ${scheduledDate.hour}:${scheduledDate.minute.toString().padLeft(2, '0')}!',
        scheduledDate: scheduledDate,
        notificationDetails: _notificationDetails(),
        androidScheduleMode: scheduleMode,
        payload: 'route:/test_scheduled',
      );

      debugPrint('Scheduled Test Notification (ID $diagnosticScheduledId) at $scheduledDate.');
      await logPendingNotifications();
    } catch (e) {
      debugPrint('Failed to schedule diagnostic test notification: $e');
    }
  }

  /// Returns all currently scheduled pending notification requests.
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('Error getting pending notification requests: $e');
      return [];
    }
  }

  /// Logs all pending notification requests with IDs, titles, and payloads.
  Future<void> logPendingNotifications() async {
    final pending = await getPendingNotifications();
    debugPrint('=== FitLoop Pending Notifications (${pending.length}) ===');
    for (final p in pending) {
      debugPrint(' - ID: ${p.id} | Title: "${p.title}" | Body: "${p.body}" | Payload: "${p.payload}"');
    }
    debugPrint('========================================================');
  }

  // =========================================================================
  // 1. WORKOUT REMINDERS
  // =========================================================================

  /// Schedules repeating weekly workout reminders for selected weekdays.
  Future<void> scheduleWorkoutReminders({
    required bool enabled,
    required TimeOfDay time,
    required List<int> daysOfWeek, // 1 = Mon, 7 = Sun
  }) async {
    // Cancel existing workout reminders first to prevent duplicates
    await cancelWorkoutReminders();

    if (!enabled || daysOfWeek.isEmpty) return;

    final scheduleMode = await _getSafeScheduleMode();

    for (final day in daysOfWeek) {
      if (day < 1 || day > 7) continue;
      final int notificationId = workoutIdBase + day;
      final scheduledDate = nextInstanceOfWeekdayAndTime(day, time.hour, time.minute);

      try {
        await _notificationsPlugin.zonedSchedule(
          id: notificationId,
          title: 'Workout Time! 🏋️',
          body: 'Time to crush your scheduled workout session. Let\'s move!',
          scheduledDate: scheduledDate,
          notificationDetails: _notificationDetails(),
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'route:/workouts',
        );
        debugPrint('Scheduled Workout Reminder (ID $notificationId) for weekday $day at ${time.hour}:${time.minute.toString().padLeft(2, '0')}');
      } catch (e) {
        debugPrint('Failed to schedule workout reminder for day $day: $e');
      }
    }

    await logPendingNotifications();
  }

  Future<void> cancelWorkoutReminders() async {
    try {
      for (int day = 1; day <= 7; day++) {
        await _notificationsPlugin.cancel(id: workoutIdBase + day);
      }
    } catch (e) {
      debugPrint('Error cancelling workout reminders: $e');
    }
  }

  // =========================================================================
  // 2. MEAL LOGGING REMINDERS
  // =========================================================================

  /// Schedules daily meal reminders for breakfast, lunch, and dinner.
  Future<void> scheduleMealReminders({
    required bool breakfastEnabled,
    required TimeOfDay breakfastTime,
    required bool lunchEnabled,
    required TimeOfDay lunchTime,
    required bool dinnerEnabled,
    required TimeOfDay dinnerTime,
  }) async {
    await cancelMealReminders();

    final scheduleMode = await _getSafeScheduleMode();

    final List<Map<String, dynamic>> meals = [
      {
        'id': mealBreakfastId,
        'enabled': breakfastEnabled,
        'time': breakfastTime,
        'title': 'Breakfast Reminder 🍳',
        'body': 'Don\'t forget to log your breakfast to track your morning macros!',
      },
      {
        'id': mealLunchId,
        'enabled': lunchEnabled,
        'time': lunchTime,
        'title': 'Lunch Reminder 🥗',
        'body': 'Time to refuel! Take a moment to log your lunch nutrition.',
      },
      {
        'id': mealDinnerId,
        'enabled': dinnerEnabled,
        'time': dinnerTime,
        'title': 'Dinner Reminder 🍲',
        'body': 'Wrap up your daily food diary. Log your evening meal!',
      },
    ];

    for (final meal in meals) {
      if (meal['enabled'] != true) continue;
      final int id = meal['id'] as int;
      final TimeOfDay time = meal['time'] as TimeOfDay;
      final scheduledDate = nextInstanceOfTime(time.hour, time.minute);

      try {
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: meal['title'] as String,
          body: meal['body'] as String,
          scheduledDate: scheduledDate,
          notificationDetails: _notificationDetails(),
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'route:/diet',
        );
        debugPrint('Scheduled Meal Reminder (ID $id) at ${time.hour}:${time.minute.toString().padLeft(2, '0')}');
      } catch (e) {
        debugPrint('Failed to schedule meal reminder $id: $e');
      }
    }

    await logPendingNotifications();
  }

  Future<void> cancelMealReminders() async {
    try {
      await _notificationsPlugin.cancel(id: mealBreakfastId);
      await _notificationsPlugin.cancel(id: mealLunchId);
      await _notificationsPlugin.cancel(id: mealDinnerId);
    } catch (e) {
      debugPrint('Error cancelling meal reminders: $e');
    }
  }

  // =========================================================================
  // 3. HYDRATION REMINDERS
  // =========================================================================

  /// Schedules hydration reminders during waking hours (08:00 - 22:00) at intervalHours.
  Future<void> scheduleHydrationReminders({
    required bool enabled,
    required int intervalHours, // 2, 3, or 4
  }) async {
    await cancelHydrationReminders();

    if (!enabled || intervalHours < 1) return;

    final scheduleMode = await _getSafeScheduleMode();

    final List<int> hours = [];
    for (int h = 8 + intervalHours; h <= 22; h += intervalHours) {
      hours.add(h);
    }

    int slotIndex = 0;
    for (final hour in hours) {
      slotIndex++;
      final int id = hydrationIdBase + slotIndex;
      final scheduledDate = nextInstanceOfTime(hour, 0);

      try {
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: 'Stay Hydrated! 💧',
          body: 'Remember to drink a glass of water to keep your body performing at its peak.',
          scheduledDate: scheduledDate,
          notificationDetails: _notificationDetails(),
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'route:/home',
        );
        debugPrint('Scheduled Hydration Reminder (ID $id) at $hour:00');
      } catch (e) {
        debugPrint('Failed to schedule hydration reminder $id: $e');
      }
    }

    await logPendingNotifications();
  }

  Future<void> cancelHydrationReminders() async {
    try {
      for (int i = 1; i <= 10; i++) {
        await _notificationsPlugin.cancel(id: hydrationIdBase + i);
      }
    } catch (e) {
      debugPrint('Error cancelling hydration reminders: $e');
    }
  }

  // =========================================================================
  // 4. WEEKLY PROGRESS REMINDER
  // =========================================================================

  /// Schedules weekly summary notification (e.g. Sunday at 20:00).
  Future<void> scheduleWeeklyProgressReminder({
    required bool enabled,
    required int dayOfWeek, // 1 = Mon, 7 = Sun
    required TimeOfDay time,
  }) async {
    await cancelWeeklyProgressReminder();

    if (!enabled) return;

    final scheduleMode = await _getSafeScheduleMode();
    final scheduledDate = nextInstanceOfWeekdayAndTime(dayOfWeek, time.hour, time.minute);

    try {
      await _notificationsPlugin.zonedSchedule(
        id: weeklyProgressId,
        title: 'Weekly Progress Update 📈',
        body: 'Your weekly FitLoop progress summary is ready. Tap to view your achievements!',
        scheduledDate: scheduledDate,
        notificationDetails: _notificationDetails(),
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'route:/analytics',
      );
      debugPrint('Scheduled Weekly Progress Reminder (ID $weeklyProgressId) on weekday $dayOfWeek at ${time.hour}:${time.minute.toString().padLeft(2, '0')}');
    } catch (e) {
      debugPrint('Failed to schedule weekly progress reminder: $e');
    }

    await logPendingNotifications();
  }

  Future<void> cancelWeeklyProgressReminder() async {
    try {
      await _notificationsPlugin.cancel(id: weeklyProgressId);
    } catch (e) {
      debugPrint('Error cancelling weekly progress reminder: $e');
    }
  }

  // =========================================================================
  // MASTER SYNC & LIFECYCLE
  // =========================================================================

  /// Cancels all FitLoop notifications.
  Future<void> cancelAll() async {
    try {
      await cancelWorkoutReminders();
      await cancelMealReminders();
      await cancelHydrationReminders();
      await cancelWeeklyProgressReminder();
      await _notificationsPlugin.cancelAll();
      debugPrint('All FitLoop notifications cancelled.');
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }

  /// Synchronizes all reminder settings with the local scheduler.
  Future<void> syncAllReminders(
    Map<String, dynamic> remindersData, {
    required bool masterEnabled,
  }) async {
    if (!masterEnabled) {
      await cancelAll();
      return;
    }

    // 1. Workout Reminders
    final workout = remindersData['workout'] is Map ? remindersData['workout'] as Map : {};
    final bool workoutEnabled = workout['enabled'] == true;
    final int workoutHour = (workout['hour'] as num?)?.toInt() ?? 19;
    final int workoutMinute = (workout['minute'] as num?)?.toInt() ?? 0;
    final List<int> workoutDays = workout['days'] is List
        ? (workout['days'] as List).map((d) => (d as num).toInt()).toList()
        : [1, 3, 5]; // Default Mon, Wed, Fri

    await scheduleWorkoutReminders(
      enabled: workoutEnabled,
      time: TimeOfDay(hour: workoutHour, minute: workoutMinute),
      daysOfWeek: workoutDays,
    );

    // 2. Meal Logging Reminders
    final meals = remindersData['meals'] is Map ? remindersData['meals'] as Map : {};
    final bool breakfastEnabled = meals['breakfastEnabled'] == true;
    final int bHour = (meals['breakfastHour'] as num?)?.toInt() ?? 8;
    final int bMin = (meals['breakfastMinute'] as num?)?.toInt() ?? 30;

    final bool lunchEnabled = meals['lunchEnabled'] == true;
    final int lHour = (meals['lunchHour'] as num?)?.toInt() ?? 12;
    final int lMin = (meals['lunchMinute'] as num?)?.toInt() ?? 30;

    final bool dinnerEnabled = meals['dinnerEnabled'] == true;
    final int dHour = (meals['dinnerHour'] as num?)?.toInt() ?? 19;
    final int dMin = (meals['dinnerMinute'] as num?)?.toInt() ?? 30;

    await scheduleMealReminders(
      breakfastEnabled: breakfastEnabled,
      breakfastTime: TimeOfDay(hour: bHour, minute: bMin),
      lunchEnabled: lunchEnabled,
      lunchTime: TimeOfDay(hour: lHour, minute: lMin),
      dinnerEnabled: dinnerEnabled,
      dinnerTime: TimeOfDay(hour: dHour, minute: dMin),
    );

    // 3. Hydration Reminders
    final hydration = remindersData['hydration'] is Map ? remindersData['hydration'] as Map : {};
    final bool hydrationEnabled = hydration['enabled'] == true;
    final int intervalHours = (hydration['intervalHours'] as num?)?.toInt() ?? 2;

    await scheduleHydrationReminders(
      enabled: hydrationEnabled,
      intervalHours: intervalHours,
    );

    // 4. Weekly Progress
    final weekly = remindersData['weeklyProgress'] is Map ? remindersData['weeklyProgress'] as Map : {};
    final bool weeklyEnabled = weekly['enabled'] == true;
    final int dayOfWeek = (weekly['dayOfWeek'] as num?)?.toInt() ?? 7; // Sunday
    final int wHour = (weekly['hour'] as num?)?.toInt() ?? 20;
    final int wMinute = (weekly['minute'] as num?)?.toInt() ?? 0;

    await scheduleWeeklyProgressReminder(
      enabled: weeklyEnabled,
      dayOfWeek: dayOfWeek,
      time: TimeOfDay(hour: wHour, minute: wMinute),
    );
  }

  // =========================================================================
  // TIMEZONE DATE HELPERS
  // =========================================================================

  /// Calculates the next instance of a specific time in local timezone.
  tz.TZDateTime nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    // Explicitly zero out seconds and milliseconds so second discrepancies don't push to tomorrow
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute, 0);

    // If already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    debugPrint('--- Scheduling Time Calculation ---');
    debugPrint('Device local DateTime: ${DateTime.now()}');
    debugPrint('Timezone location: ${tz.local.name}');
    debugPrint('Current TZDateTime: $now');
    debugPrint('Target Time: $hour:${minute.toString().padLeft(2, '0')}');
    debugPrint('Scheduled TZDateTime: $scheduledDate (fires in ${scheduledDate.difference(now).inMinutes} minutes)');
    debugPrint('-----------------------------------');

    return scheduledDate;
  }

  /// Calculates the next instance of a specific weekday (1 = Mon, 7 = Sun) and time.
  tz.TZDateTime nextInstanceOfWeekdayAndTime(int weekday, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute, 0);

    // If target time today has already passed, advance to next day
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Advance until matching target weekday
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    debugPrint('--- Weekday Scheduling Calculation ---');
    debugPrint('Device local DateTime: ${DateTime.now()} (Current weekday: ${DateTime.now().weekday})');
    debugPrint('Target weekday: $weekday | Target Time: $hour:${minute.toString().padLeft(2, '0')}');
    debugPrint('Timezone location: ${tz.local.name}');
    debugPrint('Current TZDateTime: $now');
    debugPrint('Scheduled TZDateTime: $scheduledDate (fires in ${scheduledDate.difference(now).inHours} hours)');
    debugPrint('--------------------------------------');

    return scheduledDate;
  }
}
