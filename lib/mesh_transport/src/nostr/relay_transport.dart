import 'package:nostr/nostr.dart';

import 'relay_client.dart';

/// What the bridge needs from a relay, whether that is one relay or several.
///
/// Exists so a pool can stand in for a single client without the bridge
/// knowing which it has. Dart has no structural typing, so the shared surface
/// has to be written down.
abstract class RelayTransport {
  Stream<Event> get events;

  Stream<PublishResult> get results;

  Stream<String> get notices;

  /// True when at least one relay is reachable, false when none are.
  Stream<bool> get connectionChanges;

  bool get isConnected;

  void open();

  /// Reconnects at once if down, instead of waiting out the backoff.
  ///
  /// For the moment the app comes back to the foreground: the socket was
  /// most likely cut while it was away, and the backoff by then can be half
  /// a minute, which is a long time to look offline for no reason.
  void nudge();

  String subscribe(List<Filter> filters, {String? subscriptionId});

  void unsubscribe(String subscriptionId);

  void publish(Event event);

  Future<void> close();
}
