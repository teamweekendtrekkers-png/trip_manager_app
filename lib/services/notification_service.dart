import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract interface class DeploymentNotificationClient {
  Future<bool> requestPermission();

  Future<void> showDeploymentNotification({
    required bool success,
    String? commitMessage,
  });
}

class NotificationService implements DeploymentNotificationClient {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionRequested = false;
  bool _permissionGranted = true;

  /// Initialize the notification plugin. Call once at app startup.
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: initSettings);
    _initialized = true;
  }

  /// Request Android 13+ notification permission when deployment monitoring
  /// actually begins, rather than during app startup.
  @override
  Future<bool> requestPermission() async {
    if (_permissionRequested) return _permissionGranted;
    await init();
    _permissionRequested = true;
    final result = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _permissionGranted = result ?? true;
    return _permissionGranted;
  }

  /// Show a deployment-complete notification.
  @override
  Future<void> showDeploymentNotification({
    required bool success,
    String? commitMessage,
  }) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'deployment_status',
      'Deployment Status',
      channelDescription: 'Notifications for website deployment status',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    final title = success ? '✅ Deployment Successful' : '❌ Deployment Failed';
    final body = success
        ? commitMessage != null
              ? 'Website deployed: $commitMessage'
              : 'Website is live with the latest changes'
        : commitMessage != null
        ? 'Deployment failed: $commitMessage'
        : 'Deployment failed — check workflow logs';

    await _plugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
