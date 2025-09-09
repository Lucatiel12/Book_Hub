import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _downloadChannel =
      AndroidNotificationChannel(
        'bookhub_downloads',
        'BookHub Downloads',
        description: 'Status of book downloads (complete, failed, paused)',
        importance: Importance.high,
      );

  Future<void> init() async {
    // Android init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS init
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(initSettings);

    // Create Android channel
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_downloadChannel);

    // Ask user permissions on iOS/macOS
    if (Platform.isIOS || Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  // Helper: stable ID per bookId (keeps one notification per book)
  int _idFor(String bookId) => bookId.hashCode & 0x7FFFFFFF;

  Future<void> showCompleted(String bookId, String title) async {
    final id = _idFor(bookId);
    await _plugin.show(
      id,
      'Download completed',
      title,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _downloadChannel.id,
          _downloadChannel.name,
          channelDescription: _downloadChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.progress,
          styleInformation: const DefaultStyleInformation(true, true),
          autoCancel: true,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> showFailed(String bookId, String title, {String? reason}) async {
    final id = _idFor(bookId);
    await _plugin.show(
      id,
      'Download failed',
      reason?.isNotEmpty == true ? '$title — $reason' : title,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _downloadChannel.id,
          _downloadChannel.name,
          channelDescription: _downloadChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFFD32F2F),
          styleInformation: const DefaultStyleInformation(true, true),
          autoCancel: true,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> showPausedForWifi(String bookId, String title) async {
    final id = _idFor(bookId);
    await _plugin.show(
      id,
      'Paused (Wi-Fi only)',
      'Waiting for Wi-Fi — $title',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _downloadChannel.id,
          _downloadChannel.name,
          channelDescription: _downloadChannel.description,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: const DefaultStyleInformation(true, true),
          autoCancel: true,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
