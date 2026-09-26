import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Asks the platform not to wind the process down while the radio listens.
///
/// Android throttles a background scan and kills a quiet process; a
/// foreground service with a notification is the sanctioned way to say
/// "this app is doing something the user asked for". iOS handles the same
/// need through the background modes in Info.plist and needs nothing at
/// runtime, so there this is a no-op.
abstract class KeepAlive {
  Future<void> acquire();

  Future<void> release();
}

/// For tests and for platforms with nothing to do.
class NoKeepAlive implements KeepAlive {
  const NoKeepAlive();

  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}
}

/// The Android foreground service, over a method channel to MainActivity.
class PlatformKeepAlive implements KeepAlive {
  const PlatformKeepAlive({
    this.channel = const MethodChannel(channelName),
    TargetPlatform? platform,
  }) : _platform = platform;

  static const channelName = 'cash.radius/keep_alive';

  final MethodChannel channel;
  final TargetPlatform? _platform;

  bool get _isAndroid =>
      !kIsWeb && (_platform ?? defaultTargetPlatform) == TargetPlatform.android;

  @override
  Future<void> acquire() => _call('acquire');

  @override
  Future<void> release() => _call('release');

  Future<void> _call(String method) async {
    if (!_isAndroid) return;
    try {
      await channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // A host without the native side, such as a test harness. The radio
      // still works, it just does not outlive the screen.
    } on PlatformException {
      // Same outcome. Nothing the caller can do about it.
    }
  }
}
