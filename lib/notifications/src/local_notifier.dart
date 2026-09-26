import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notifier.dart';

/// [Notifier] over flutter_local_notifications.
///
/// Nothing is scheduled and nothing is repeated; every alert is shown the
/// moment the app learns the thing it is about. One channel, high enough to
/// make a sound, because a claim on your bounty is the whole point of having
/// the app in your pocket.
class LocalNotifier implements Notifier {
  LocalNotifier({
    required this.channelName,
    required this.channelDescription,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'bounties';

  /// Shown by the system in its notification settings.
  final String channelName;
  final String channelDescription;

  final FlutterLocalNotificationsPlugin _plugin;
  final _opened = StreamController<String>.broadcast();
  bool _initialized = false;

  /// Has to run before anything else, and only once.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Asked for later, at a moment that makes sense to the user, not the
        // instant the app opens.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.isNotEmpty && !_opened.isClosed) {
          _opened.add(route);
        }
      },
    );
  }

  @override
  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  @override
  Future<void> show(Alert alert) => _plugin.show(
    id: alert.id,
    title: alert.title,
    body: alert.body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    ),
    payload: alert.route,
  );

  @override
  Stream<String> get opened => _opened.stream;

  @override
  Future<String?> launchRoute() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final route = details.notificationResponse?.payload;
    return (route == null || route.isEmpty) ? null : route;
  }

  Future<void> dispose() => _opened.close();
}
