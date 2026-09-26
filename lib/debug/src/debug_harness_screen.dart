import 'dart:async';

import 'package:flutter/material.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/mesh_transport/mesh_transport.dart';
import 'package:radius/repositories/bounty_repository/bounty_repository.dart';
import 'package:radius/repositories/identity_repository/identity_repository.dart';
import 'package:radius/repositories/location_repository/location_repository.dart';
import 'package:radius/repositories/mesh_repository/mesh_repository.dart';

/// Everything the real app will do through six screens, on one page.
///
/// Takes the link as well as the repositories, which no real screen ever
/// should: the log lines are the whole point of this thing and the mesh
/// repository does not carry them. That shortcut dies with the folder.
class DebugHarnessScreen extends StatefulWidget {
  const DebugHarnessScreen({
    required this.identityRepository,
    required this.meshRepository,
    required this.bountyRepository,
    required this.locationRepository,
    required this.link,
    required this.onIdentityForgotten,
    super.key,
  });

  final IdentityRepository identityRepository;
  final MeshRepository meshRepository;
  final BountyRepository bountyRepository;
  final LocationRepository locationRepository;
  final Future<MeshLink> link;
  final VoidCallback onIdentityForgotten;

  @override
  State<DebugHarnessScreen> createState() => _DebugHarnessScreenState();
}

class _DebugHarnessScreenState extends State<DebugHarnessScreen> {
  static const _maxLines = 500;

  final _lines = <_Line>[];
  final _scroll = ScrollController();

  StreamSubscription<LogLine>? _logs;
  StreamSubscription<List<Bounty>>? _bounties;
  StreamSubscription<List<Claim>>? _claims;
  StreamSubscription<List<Witness>>? _witnesses;
  StreamSubscription<BountyCacheException>? _cacheFailures;

  Identity? _identity;
  var _bountyList = <Bounty>[];
  var _claimList = <Claim>[];
  var _witnessList = <Witness>[];
  var _posted = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    _bounties = widget.bountyRepository.getBounties().listen(
      (b) => setState(() => _bountyList = b),
      onError: (Object e) => _say('bounties stream: ${_why(e)}'),
    );
    _claims = widget.bountyRepository.getClaims().listen(
      (c) => setState(() => _claimList = c),
      onError: (Object e) => _say('claims stream: ${_why(e)}'),
    );
    _witnesses = widget.bountyRepository.getWitnesses().listen(
      (w) => setState(() => _witnessList = w),
      onError: (Object e) => _say('witnesses stream: ${_why(e)}'),
    );
    _cacheFailures = widget.bountyRepository.cacheFailures.listen(
      (e) => _say('cache: ${_why(e)}'),
    );

    try {
      final identity = await widget.identityRepository.getIdentity();
      setState(() => _identity = identity);
      _say('i am ${identity.shortId} (${identity.origin.name})');
    } catch (e) {
      _say('identity: ${_why(e)}');
      return;
    }

    // The link is the only source of log lines, so subscribe before the
    // radio comes up or the first half of the startup is invisible.
    try {
      final link = await widget.link;
      _logs = link.logs.listen(
        (l) => _say(l.text, level: l.level, stamp: l.stamp),
      );
    } catch (e) {
      _say('link: ${_why(e)}');
    }

    await _run('start mesh', widget.meshRepository.start);
    await _run('start relays', widget.meshRepository.startRelays);
  }

  /// Runs a repository call and reports whichever way it went. Every button
  /// goes through here so a thrown domain exception lands in the log rather
  /// than in a zone nobody is watching.
  Future<void> _run(String what, Future<void> Function() op) async {
    _say('$what ...');
    try {
      await op();
      _say('$what ok');
    } catch (e) {
      _say('$what failed: ${_why(e)}', level: LogLevel.error);
    }
  }

  void _say(String text, {LogLevel level = LogLevel.info, String? stamp}) {
    if (!mounted) return;
    setState(() {
      _lines.add(_Line(stamp ?? _stampNow(), level, text));
      if (_lines.length > _maxLines) _lines.removeRange(0, 100);
    });
    // After the frame that has the new line in it, or there is nothing to
    // scroll to yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  String _stampNow() {
    final t = DateTime.now();
    return '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}.'
        '${t.millisecond.toString().padLeft(3, '0')}';
  }

  /// Domain exceptions carry nothing but their type, which is the whole
  /// message.
  String _why(Object e) => e.runtimeType.toString();

  // Post a bounty from this phone. A real amount and an hour to run, so the
  // other phone sees something plausible.
  Future<void> _post() => _run('post', () async {
    Geohash? where;
    try {
      where = await widget.locationRepository.currentGeohash();
    } catch (e) {
      // A fix is optional. Without one the listing just has no area.
      _say('no position (${_why(e)}), posting without one');
    }
    _posted++;
    final bounty = await widget.bountyRepository.postBounty(
      title: 'Test ${_identity?.shortId ?? '?'} #$_posted',
      details: 'Posted from the debug harness.',
      amountCents: 500 * _posted,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      geohash: where,
    );
    _say('posted ${bounty.id} "${bounty.title}"');
  });

  /// Claims the newest bounty from the other phone. The repository refuses
  /// our own, so there is nothing to choose between.
  Future<void> _claim() {
    final theirs = _bountyList
        .where((b) => !b.isMine && b.status == BountyStatus.open)
        .firstOrNull;
    if (theirs == null) return _nothing('nothing of theirs to claim');
    return _run('claim ${theirs.title}', () async {
      await widget.bountyRepository.claim(theirs.id, note: 'I will do it');
    });
  }

  /// Accepts the first pending claim on anything of mine.
  Future<void> _accept() {
    final pending = _claimList
        .where((c) => !c.isMine && c.status == ClaimStatus.pending)
        .firstOrNull;
    if (pending == null) return _nothing('no pending claim on mine');
    return _run('accept ${pending.claimantLabel}', () async {
      await widget.bountyRepository.accept(
        pending.bountyId,
        pending.claimantId,
      );
    });
  }

  /// Marks done whatever this phone has standing in: my claimed bounty as
  /// the author, or the one I was accepted for as the claimant.
  Future<void> _markDone() {
    final mine = _bountyList
        .where((b) => b.status == BountyStatus.claimed)
        .where((b) => b.isMine || b.claimantId == _identity?.peerId)
        .firstOrNull;
    if (mine == null) return _nothing('nothing claimed to finish');
    return _run('done ${mine.title}', () async {
      await widget.bountyRepository.markDone(mine.id);
    });
  }

  /// Asks the room again to co-sign a completion this phone claimed.
  /// markDone already asks once; this is for the third phone that walked in
  /// afterwards.
  Future<void> _witness() {
    final mine = _bountyList
        .where((b) => b.claimantId == _identity?.peerId)
        .firstOrNull;
    if (mine == null) return _nothing('nothing of mine to be witnessed');
    return _run(
      'witness ${mine.title}',
      () => widget.bountyRepository.requestWitnesses(mine.id),
    );
  }

  Future<void> _nothing(String why) async => _say(why, level: LogLevel.warn);

  @override
  void dispose() {
    unawaited(_logs?.cancel());
    unawaited(_bounties?.cancel());
    unawaited(_claims?.cancel());
    unawaited(_witnesses?.cancel());
    unawaited(_cacheFailures?.cancel());
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('radius debug ${_identity?.shortId ?? ''}'),
      actions: [
        IconButton(
          onPressed: () => setState(_lines.clear),
          icon: const Icon(Icons.clear_all),
          tooltip: 'clear log',
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          _status(),
          const Divider(height: 1),
          _buttons(),
          const Divider(height: 1),
          Expanded(child: _log()),
        ],
      ),
    ),
  );

  Widget _status() => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<MeshStatus>(
          stream: widget.meshRepository.getMeshStatus(),
          builder: (context, snapshot) {
            final s = snapshot.data ?? MeshStatus.stopped;
            return Text(
              'mesh ${s.phase.name}  peers ${s.peerCount}  '
              'nearby ${s.nearbyDeviceCount}',
            );
          },
        ),
        StreamBuilder<RelayStatus>(
          stream: widget.meshRepository.getRelayStatus(),
          builder: (context, snapshot) =>
              Text('relays ${(snapshot.data ?? RelayStatus.stopped).name}'),
        ),
        StreamBuilder<List<Peer>>(
          stream: widget.meshRepository.getPeers(),
          builder: (context, snapshot) => Text(
            'reachable ${(snapshot.data ?? const <Peer>[]).map((p) => p.label).join(' ')}',
          ),
        ),
        Text(
          'bounties ${_bountyList.length}  claims ${_claimList.length}  '
          'witnesses ${_witnessList.length}',
        ),
        if (_witnessList.isNotEmpty)
          Text(
            'witnessed by ${_witnessList.map((w) => w.witnessLabel).join(' ')}',
          ),
      ],
    ),
  );

  Widget _buttons() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Wrap(
      spacing: 8,
      children: [
        TextButton(onPressed: _post, child: const Text('post')),
        TextButton(onPressed: _claim, child: const Text('claim')),
        TextButton(onPressed: _accept, child: const Text('accept')),
        TextButton(onPressed: _markDone, child: const Text('done')),
        TextButton(onPressed: _witness, child: const Text('witness')),
        TextButton(
          onPressed: () => _run('stop mesh', widget.meshRepository.stop),
          child: const Text('stop'),
        ),
        TextButton(
          onPressed: () => _run('start mesh', widget.meshRepository.start),
          child: const Text('start'),
        ),
        TextButton(
          onPressed: () => _run('forget', () async {
            await widget.identityRepository.forgetIdentity();
            widget.onIdentityForgotten();
          }),
          child: const Text('forget'),
        ),
      ],
    ),
  );

  Widget _log() => ListView.builder(
    controller: _scroll,
    padding: const EdgeInsets.all(8),
    itemCount: _lines.length,
    itemBuilder: (context, i) {
      final line = _lines[i];
      return Text(
        '${line.stamp} ${line.text}',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: switch (line.level) {
            LogLevel.error => Colors.red,
            LogLevel.warn => Colors.orange,
            LogLevel.tx => Colors.blue,
            LogLevel.rx => Colors.green,
            LogLevel.info => null,
          },
        ),
      );
    },
  );
}

class _Line {
  const _Line(this.stamp, this.level, this.text);

  final String stamp;
  final LogLevel level;
  final String text;
}
