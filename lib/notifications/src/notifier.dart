import 'dart:async';

/// One thing worth telling the user about.
class Alert {
  const Alert({
    required this.id,
    required this.title,
    required this.body,
    required this.route,
  });

  /// Stable per subject, so a second alert about the same bounty replaces
  /// the first instead of stacking.
  final int id;
  final String title;
  final String body;

  /// Where a tap takes the user, as a router path.
  final String route;
}

/// The platform's notification tray, as much of it as this app needs.
abstract class Notifier {
  /// Asks the user once. A refusal is not an error: alerts simply do not show.
  Future<void> requestPermission();

  Future<void> show(Alert alert);

  /// Routes of alerts the user tapped while the app was running.
  Stream<String> get opened;

  /// The route of the alert that launched the app, if one did.
  Future<String?> launchRoute();
}

/// For tests, and for a host with no tray.
class NoNotifier implements Notifier {
  const NoNotifier();

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> show(Alert alert) async {}

  @override
  Stream<String> get opened => const Stream.empty();

  @override
  Future<String?> launchRoute() async => null;
}
