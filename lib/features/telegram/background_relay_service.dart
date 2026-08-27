import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String kTelegramBackgroundChannelId = 'telegram_relay_channel';
const int kTelegramNotificationId = 888;

/// Configures and registers the 24/7 background foreground service for Android.
Future<void> initializeBackgroundRelayService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    kTelegramBackgroundChannelId,
    'PocketStrike 24/7 Background Relay',
    description: 'Keeps PocketStrike AI Agent connected to Telegram in the background',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onBackgroundServiceStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: kTelegramBackgroundChannelId,
      initialNotificationTitle: '⚡ PocketStrike Agent Online',
      initialNotificationContent: '24/7 Telegram AI Relay Active',
      foregroundServiceNotificationId: kTelegramNotificationId,
      foregroundServiceTypes: [
        AndroidForegroundType.dataSync,
        AndroidForegroundType.specialUse,
      ],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onBackgroundServiceStart,
    ),
  );
}

@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Keep background process alive and update status periodically
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        final now = DateTime.now();
        final timeStr =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        service.setForegroundNotificationInfo(
          title: '⚡ PocketStrike AI Agent',
          content: '24/7 Telegram Relay Active • Last ping $timeStr',
        );
      }
    }
  });
}
