import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr/nostr.dart' hide Tags;
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/keep_alive/keep_alive.dart';
import 'package:radius/mesh_transport/mesh_transport.dart';
import 'package:radius/repositories/mesh_repository/mesh_repository.dart';

class _MockMeshLink extends Mock implements MeshLink {}

class _FakeKeepAlive implements KeepAlive {
  int acquired = 0;
  int released = 0;

  @override
  Future<void> acquire() async => acquired++;

  @override
  Future<void> release() async => released++;
}

class _FakeRelays implements RelayTransport {
  final connection = StreamController<bool>.broadcast();
  bool opened = false;
  bool closed = false;

  @override
  Stream<bool> get connectionChanges => connection.stream;

  @override
  Stream<Event> get events => const Stream.empty();

  @override
  Stream<PublishResult> get results => const Stream.empty();

  @override
  Stream<String> get notices => const Stream.empty();

  @override
  bool get isConnected => false;

  @override
  void open() => opened = true;

  int nudged = 0;

  @override
  void nudge() => nudged++;

  @override
  String subscribe(List<Filter> filters, {String? subscriptionId}) => 'sub';

  @override
  void unsubscribe(String subscriptionId) {}

  @override
  void publish(Event event) {}

  @override
  Future<void> close() async {
    closed = true;
    await connection.close();
  }
}

void main() {
  final seed = Uint8List.fromList(List.generate(32, (i) => 32 - i));
  late NodeIdentity node;
  late _MockMeshLink link;
  late _FakeRelays relays;
  late _FakeKeepAlive keepAlive;
  late StreamController<LogLine> logs;

  setUpAll(() async => node = await NodeIdentity.fromSeed(seed));

  setUp(() {
    link = _MockMeshLink();
    relays = _FakeRelays();
    keepAlive = _FakeKeepAlive();
    logs = StreamController<LogLine>.broadcast();
    when(() => link.identity).thenReturn(node);
    when(() => link.logs).thenAnswer((_) => logs.stream);
    when(() => link.addressablePeers).thenReturn(const []);
    when(() => link.sessionPeers).thenReturn(const []);
    when(() => link.observed).thenReturn(const []);
    when(() => link.running).thenReturn(false);
    when(() => link.wantRunning).thenReturn(false);
    when(() => link.state).thenReturn(BluetoothLowEnergyState.poweredOn);
    when(() => link.start()).thenAnswer((_) async {});
    when(() => link.stop()).thenAnswer((_) async {});
    when(() => link.send(any())).thenAnswer((_) async {});
    when(() => link.sendSealed(any(), any())).thenAnswer((_) async {});
    when(() => link.note(any())).thenReturn(null);
    when(() => link.dispose()).thenAnswer((_) async {});
  });

  MeshRepository build({Future<MeshLink>? failedLink}) => MeshRepository(
    link: failedLink ?? Future.value(link),
    relays: Future.value(relays),
    keepAlive: keepAlive,
  );

  group('lifecycle', () {
    test('start waits for the identity and then starts the radio', () async {
      final repository = build();
      await repository.start();
      verify(() => link.start()).called(1);
    });

    test('a radio that will not start is a domain exception', () async {
      when(() => link.start()).thenThrow(StateError('no adapter'));
      final repository = build();
      expect(repository.start(), throwsA(isA<MeshUnavailableException>()));
    });

    test('a refused permission surfaces even though start returned', () async {
      // The link logs and returns in that case rather than throwing, and a
      // caller that only saw the Future would think all was well.
      when(() => link.state).thenReturn(BluetoothLowEnergyState.unauthorized);
      // The real link records the intent to run before it checks the radio.
      when(() => link.wantRunning).thenReturn(true);
      final repository = build();
      expect(repository.start(), throwsA(isA<MeshUnavailableException>()));
    });

    test(
      'an identity that failed to load fails every call the same way',
      () async {
        final repository = build(failedLink: Future.error(StateError('vault')));
        expect(repository.start(), throwsA(isA<IdentityLoadException>()));
      },
    );

    test('stop tears the radio down and reports it', () async {
      final repository = build();
      final seen = <MeshStatus>[];
      final sub = repository.getMeshStatus().listen(seen.add);
      await repository.stop();
      await Future<void>.delayed(Duration.zero);
      verify(() => link.stop()).called(1);
      expect(seen.last.phase, MeshPhase.stopped);
      await sub.cancel();
    });

    test('a radio that will not stop is a domain exception', () {
      when(() => link.stop()).thenThrow(StateError('adapter gone'));
      final repository = build();
      expect(repository.stop(), throwsA(isA<MeshUnavailableException>()));
    });

    test('a running radio holds the process up, stopping lets go', () async {
      final repository = build();
      await repository.start();
      expect(keepAlive.acquired, 1);
      expect(keepAlive.released, 0);
      await repository.stop();
      expect(keepAlive.released, 1);
    });

    test('a radio that could not start does not hold anything', () async {
      when(() => link.state).thenReturn(BluetoothLowEnergyState.unauthorized);
      when(() => link.wantRunning).thenReturn(true);
      final repository = build();
      await expectLater(
        repository.start(),
        throwsA(isA<MeshUnavailableException>()),
      );
      expect(keepAlive.acquired, 0);
    });

    test('dispose lets the process go', () async {
      final repository = build();
      await repository.start();
      await repository.dispose();
      expect(keepAlive.released, 1);
    });

    test('dispose completes even when the identity never loaded', () async {
      final repository = build(failedLink: Future.error(StateError('vault')));
      await repository.dispose();
    });
  });

  group('sending', () {
    test('refuses while stopped', () {
      final repository = build();
      expect(
        repository.sendText('hello'),
        throwsA(isA<MeshNotRunningException>()),
      );
    });

    test('a write the radio rejects is a domain exception', () {
      when(() => link.running).thenReturn(true);
      when(() => link.send(any())).thenThrow(StateError('gatt'));
      final repository = build();
      expect(repository.sendText('x'), throwsA(isA<MeshSendException>()));
    });

    test('goes through when running', () async {
      when(() => link.running).thenReturn(true);
      final repository = build();
      await repository.sendText('hello');
      await repository.sendSealedText(peerId: 'abc', text: 'psst');
      verify(() => link.send('hello')).called(1);
      verify(() => link.sendSealed('abc', 'psst')).called(1);
    });
  });

  group('observing', () {
    test('peers are re-read when the link logs, once per burst', () async {
      final repository = build();
      final seen = <List<Peer>>[];
      final sub = repository.getPeers().listen(seen.add);
      await Future<void>.delayed(Duration.zero);

      when(() => link.addressablePeers).thenReturn(['0011223344556677']);
      when(() => link.reachableOnMesh(any())).thenReturn(true);
      when(() => link.nostrAddressFor(any())).thenReturn(null);
      for (var i = 0; i < 5; i++) {
        logs.add(LogLine(LogLevel.info, 'line $i'));
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(seen.last, hasLength(1));
      expect(seen.last.single.id, '0011223344556677');
      // Seeded empty, then one snapshot for the whole burst.
      expect(seen, hasLength(2));
      await sub.cancel();
    });

    test('status follows start and stop without waiting for a log', () async {
      final repository = build();
      final seen = <MeshStatus>[];
      final sub = repository.getMeshStatus().listen(seen.add);
      await Future<void>.delayed(Duration.zero);

      when(() => link.running).thenReturn(true);
      when(() => link.wantRunning).thenReturn(true);
      await repository.start();
      await Future<void>.delayed(Duration.zero);

      expect(seen.last.phase, MeshPhase.running);
      await sub.cancel();
    });
  });

  group('resuming', () {
    test('a radio that wants to run but is not is started again', () async {
      when(() => link.wantRunning).thenReturn(true);
      when(() => link.running).thenReturn(false);
      final repository = build();
      await repository.resume();
      verify(() => link.start()).called(1);
    });

    test('a radio that is running is left alone', () async {
      when(() => link.wantRunning).thenReturn(true);
      when(() => link.running).thenReturn(true);
      final repository = build();
      await repository.resume();
      verifyNever(() => link.start());
    });

    test('a radio the user stopped stays stopped', () async {
      when(() => link.wantRunning).thenReturn(false);
      final repository = build();
      await repository.resume();
      verifyNever(() => link.start());
    });

    test('a radio that fails to restart is not an error', () async {
      when(() => link.wantRunning).thenReturn(true);
      when(() => link.start()).thenThrow(StateError('adapter'));
      final repository = build();
      await repository.resume();
    });

    test('relays are nudged only once the bridge is up', () async {
      final repository = build();
      await repository.resume();
      expect(relays.nudged, 0);
      await repository.startRelays();
      await repository.resume();
      expect(relays.nudged, 1);
    });
  });

  group('relays', () {
    test('starting wires the link to the bridge', () async {
      final repository = build();
      await repository.startRelays();

      final captured =
          verify(() => link.nostrPublicKey = captureAny()).captured.single
              as String?;
      expect(captured, hasLength(64));
      verify(() => link.nostrSend = any(that: isNotNull)).called(1);
      expect(relays.opened, isTrue);
    });

    test('status follows the pool', () async {
      final repository = build();
      final seen = <RelayStatus>[];
      final sub = repository.getRelayStatus().listen(seen.add);
      await repository.startRelays();
      relays.connection.add(true);
      await Future<void>.delayed(Duration.zero);

      expect(seen, [
        RelayStatus.stopped,
        RelayStatus.connecting,
        RelayStatus.connected,
      ]);
      await sub.cancel();
    });

    test('stopping unwires but leaves the shared pool open', () async {
      // The pool also carries the public board, so only dispose closes it.
      final repository = build();
      await repository.startRelays();
      await repository.stopRelays();

      verify(() => link.nostrSend = null).called(1);
      verify(() => link.nostrPublicKey = null).called(1);
      expect(relays.closed, isFalse);

      await repository.dispose();
      expect(relays.closed, isTrue);
    });

    test('stopping without starting is a no-op', () async {
      final repository = build();
      await repository.stopRelays();
      verifyNever(() => link.nostrSend = any());
      expect(relays.closed, isFalse);
    });

    test('starting twice is one bridge', () async {
      final repository = build();
      await repository.startRelays();
      await repository.startRelays();
      verify(() => link.nostrSend = any(that: isNotNull)).called(1);
    });
  });
}
