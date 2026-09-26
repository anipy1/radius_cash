import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radius/keep_alive/keep_alive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(PlatformKeepAlive.channelName);
  late List<String> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('on Android, acquire and release reach the platform', () async {
    const keepAlive = PlatformKeepAlive(platform: TargetPlatform.android);
    await keepAlive.acquire();
    await keepAlive.release();
    expect(calls, ['acquire', 'release']);
  });

  test('on iOS nothing is sent; the background modes do the work', () async {
    const keepAlive = PlatformKeepAlive(platform: TargetPlatform.iOS);
    await keepAlive.acquire();
    await keepAlive.release();
    expect(calls, isEmpty);
  });

  test('a host without the native side is not an error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    const keepAlive = PlatformKeepAlive(platform: TargetPlatform.android);
    await keepAlive.acquire();
  });

  test('a platform that refuses is not an error either', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'refused');
        });
    const keepAlive = PlatformKeepAlive(platform: TargetPlatform.android);
    await keepAlive.acquire();
  });
}
