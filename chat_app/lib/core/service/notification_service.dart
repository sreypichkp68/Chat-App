import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  static const _channelId = 'incoming_call_channel';
  static const _channelName = 'Incoming Calls';
  static const _channelDescription = 'Channel for incoming call notifications';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final _incomingCallTaps = StreamController<void>.broadcast();
  Stream<void> get incomingCallTaps => _incomingCallTaps.stream;

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('ic_call_notification');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const init = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings: init,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == 'incoming_call') _incomingCallTaps.add(null);
      },
    );

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      ),
    );
  }

  Future<void> showIncomingCall(String peerName, {bool isVideo = false}) async {
    // ignore: avoid_print
    print('=== DEBUG showIncomingCall ENTER peerName=$peerName');
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: false,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      showWhen: true,
      autoCancel: false,
      ongoing: true,
      timeoutAfter: 60000,
      colorized: true,
      color: Color(0xFF34C471),
    );
    const details = NotificationDetails(android: android);
    await _plugin.show(
      id: 0,
      title: 'Incoming Call',
      body: peerName.isEmpty
          ? '${isVideo ? "Video" : "Voice"} call from someone...'
          : '$peerName is calling${isVideo ? " (video)" : ""}...',
      notificationDetails: details,
      payload: 'incoming_call',
    );
  }

  Future<void> cancelIncomingCall() async {
    await _plugin.cancel(id: 0);
  }
}
