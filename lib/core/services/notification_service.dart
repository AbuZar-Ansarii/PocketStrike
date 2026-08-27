import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<LocalNotificationService>((ref) {
  final service = LocalNotificationService();
  service.init();
  return service;
});

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool _isInitializing = false;

  Future<void> init() async {
    if (_isInitialized) return;
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _plugin.initialize(initSettings);

      // Request Android 13+ Notification permission safely
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        try {
          await androidImpl.requestNotificationsPermission();
        } catch (_) {}
      }

      _isInitialized = true;
    } catch (_) {
      _isInitialized = true;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await init();

      const androidDetails = AndroidNotificationDetails(
        'pocketstrike_reminders_channel',
        'PocketStrike Reminders & Tasks',
        channelDescription:
            'Local OS notifications for scheduled agent reminders and cron tasks.',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      const details = NotificationDetails(android: androidDetails);

      await _plugin.show(
        id,
        title,
        body,
        details,
      );
    } catch (_) {}
  }

  Future<void> showDownloadProgress({
    required int id,
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
    bool ongoing = true,
  }) async {
    try {
      await init();

      final androidDetails = AndroidNotificationDetails(
        'pocketstrike_downloads_channel',
        'Model Downloads',
        channelDescription:
            'Download progress notifications for offline AI models.',
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        maxProgress: maxProgress,
        progress: progress,
        indeterminate: maxProgress <= 0,
        ongoing: ongoing,
        onlyAlertOnce: true,
        autoCancel: !ongoing,
      );

      final details = NotificationDetails(android: androidDetails);

      await _plugin.show(
        id,
        title,
        body,
        details,
      );
    } catch (_) {}
  }

  Future<void> cancelNotification(int id) async {
    try {
      await init();
      await _plugin.cancel(id);
    } catch (_) {}
  }
}
