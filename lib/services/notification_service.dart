import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'windows_notification_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final WindowsNotificationService _windowsNotification = WindowsNotificationService();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    if (Platform.isWindows) {
      await _windowsNotification.init();
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );

    const settings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;

    // Request permissions on Android 13+
    if (Platform.isAndroid) {
      await _requestAndroidPermissions();
    }
  }

  Future<void> _requestAndroidPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      print('Android notification permission granted: $granted');
    }
  }

  Future<bool?> requestPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.requestNotificationsPermission();
    }
    // Windows doesn't need explicit permission request for notifications
    return true;
  }

  Future<void> showMessageNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;

    if (Platform.isWindows) {
      await _windowsNotification.showMessageNotification(title: title, body: body);
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'messages',
      '消息通知',
      channelDescription: '收到新消息时的通知',
      importance: Importance.high,
      priority: Priority.high,
    );

    const linuxDetails = LinuxNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  Future<void> showFileNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;

    if (Platform.isWindows) {
      await _windowsNotification.showFileNotification(title: title, body: body);
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'files',
      '文件通知',
      channelDescription: '文件传输相关通知',
      importance: Importance.high,
      priority: Priority.high,
    );

    const linuxDetails = LinuxNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  Future<void> showConnectionRequestNotification({
    required String deviceName,
  }) async {
    if (!_initialized) return;

    if (Platform.isWindows) {
      await _windowsNotification.showConnectionRequestNotification(deviceName: deviceName);
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'connections',
      '连接请求',
      channelDescription: '设备连接请求通知',
      importance: Importance.high,
      priority: Priority.high,
    );

    const linuxDetails = LinuxNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '连接请求',
      '$deviceName 请求连接到此设备',
      details,
    );
  }
}
