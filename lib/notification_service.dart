import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:xs_user/models.dart';
import 'dart:async';

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _notificationsKey = 'notification_history';
  final ValueNotifier<int> notificationCount = ValueNotifier<int>(0);

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [],
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    tz.initializeTimeZones();
    await _configureLocalTimeZone();

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );

    // Initialize notification count
    await _updateNotificationCount();
  }

  Future<void> _configureLocalTimeZone() async {
    if (kIsWeb) return;
    try {
      // Hardcode India timezone for reliability since the target audience is India
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (e) {
      debugPrint('Error setting India timezone, falling back to auto-detection: $e');
      try {
        final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (e2) {
        debugPrint('Auto-detection also failed: $e2');
      }
    }
  }

  Future<void> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }
    }
  }

  Future<void> _updateNotificationCount() async {
    final notifications = await getNotifications();
    notificationCount.value = notifications.length;
  }

  Future<void> _saveNotification(NotificationItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_notificationsKey) ?? [];
    history.insert(0, jsonEncode(item.toJson()));
    if (history.length > 30) history.removeLast();
    await prefs.setStringList(_notificationsKey, history);
    await _updateNotificationCount();
  }

  Future<List<NotificationItem>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_notificationsKey) ?? [];
    return history.map((e) => NotificationItem.fromJson(jsonDecode(e))).toList();
  }

  Future<void> clearNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationsKey);
    await _updateNotificationCount();
  }

  Future<void> removeNotification(int orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_notificationsKey) ?? [];
    history.removeWhere((e) {
      try {
        final item = NotificationItem.fromJson(jsonDecode(e));
        return item.orderId == orderId;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_notificationsKey, history);
    await _updateNotificationCount();
  }

  /// Instant notification: Hybrid approach for high reliability
  Future<void> showInstantNotification(int orderId, String location) async {
    await _requestPermissions();

    const title = 'Pick up your order!';
    final body = 'Your instant order #$orderId is ready for pickup at $location.';

    final notificationDetails = _getNotificationDetails('order_pickups_v7');

    // 1. Immediate Timer for active/recent background (Reliable for 10s delay)
    Timer(const Duration(seconds: 10), () async {
      try {
        await flutterLocalNotificationsPlugin.show(
          id: orderId,
          title: title,
          body: body,
          notificationDetails: notificationDetails,
          payload: orderId.toString(),
        );
      } catch (e) {
        debugPrint('Error showing immediate notification: $e');
      }
    });

    // 2. Persistent zonedSchedule as fallback
    try {
      final scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
      
      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id: orderId + 1000000,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: orderId.toString(),
        );
      } catch (e) {
        // Fallback to inexact if permission denied
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id: orderId + 1000000,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: orderId.toString(),
        );
      }
    } catch (e) {
      debugPrint('Error scheduling fallback: $e');
    }

    await _saveNotification(NotificationItem(
      orderId: orderId,
      title: title,
      body: body,
      timestamp: DateTime.now().add(const Duration(seconds: 10)),
      orderType: 'instant',
    ));
  }

  /// Scheduled notification for Preorder pickup
  Future<void> schedulePreorderNotification(
      int orderId, String timeBand, String location) async {
    try {
      await _requestPermissions();
      
      final times = timeBand.split(' - ');
      if (times.length < 2) return;

      final startTimeStr = times[0].trim().toUpperCase();
      final endTimeStr = times[1].trim().toUpperCase();
      final format = DateFormat('h:mma');
      
      final DateTime startTime = format.parse(startTimeStr);
      final DateTime endTime = format.parse(endTimeStr);

      final now = DateTime.now();
      var startDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        startTime.hour,
        startTime.minute,
      );
      var endDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        endTime.hour,
        endTime.minute,
      );

      DateTime scheduledDateLocal;
      String body;
      final notificationDetails = _getNotificationDetails('order_pickups_v7');

      if (now.isAfter(startDateTime) && now.isBefore(endDateTime)) {
        // Active band - trigger after 10s
        scheduledDateLocal = now.add(const Duration(seconds: 10));
        body = 'Your preorder #$orderId at $location is ready for pickup ($timeBand).';
        
        Timer(const Duration(seconds: 10), () async {
          try {
            await flutterLocalNotificationsPlugin.show(
              id: orderId,
              title: 'Pick up your order!',
              body: body,
              notificationDetails: notificationDetails,
              payload: orderId.toString(),
            );
          } catch (e) {
            debugPrint('Error showing immediate preorder: $e');
          }
        });
      } else if (startDateTime.isAfter(now)) {
        // Future band
        scheduledDateLocal = startDateTime;
        body = 'Your preorder #$orderId at $location is ready for pickup ($timeBand).';
      } else {
        return;
      }

      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id: orderId,
          title: 'Pick up your order!',
          body: body,
          scheduledDate: tz.TZDateTime.from(scheduledDateLocal, tz.local),
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: orderId.toString(),
        );
      } catch (e) {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id: orderId,
          title: 'Pick up your order!',
          body: body,
          scheduledDate: tz.TZDateTime.from(scheduledDateLocal, tz.local),
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: orderId.toString(),
        );
      }

      await _saveNotification(NotificationItem(
        orderId: orderId,
        title: 'Pick up your order!',
        body: body,
        timestamp: scheduledDateLocal,
        orderType: 'preorder',
      ));
    } catch (e) {
      debugPrint('Error scheduling preorder: $e');
    }
  }

  NotificationDetails _getNotificationDetails(String channelId) {
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      channelId,
      'Order Pickups',
      channelDescription: 'Notifications for when order is ready to pick up',
      importance: Importance.max,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound('times_up'),
      playSound: true,
      showWhen: true,
      ticker: 'Order Ready',
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      enableVibration: true,
      enableLights: true,
    );

    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'times_up.mp3',
      interruptionLevel: InterruptionLevel.critical,
    );

    return NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );
  }
}
