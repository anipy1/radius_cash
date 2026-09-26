import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:meta/meta.dart';

import 'models/bounty_cm.dart';
import 'models/claim_cm.dart';
import 'models/hive_adapters.dart';
import 'models/hive_registrar.g.dart';

/// The one place that opens Hive boxes.
///
/// Owns the box names, registers the adapters once, and initialises Hive on
/// first use so main.dart can construct it synchronously: every box getter
/// waits on the initialisation rather than asking the caller to.
class KeyValueStorage {
  KeyValueStorage({
    @visibleForTesting HiveInterface? hive,
    @visibleForTesting Future<void> Function(HiveInterface hive)? initialize,
  }) : _hive = hive ?? Hive,
       _initialize = initialize ?? _initializeForApp;

  static const _bountiesBoxKey = 'bounties';
  static const _claimsBoxKey = 'claims';
  static const _settingsBoxKey = 'settings';

  final HiveInterface _hive;
  final Future<void> Function(HiveInterface hive) _initialize;

  late final Future<void> _ready = _initialize(_hive).then((_) {
    // Guarded because hot restart runs this constructor again against the
    // same Hive, and registering twice throws.
    if (!_hive.isAdapterRegistered(BountyCMAdapter().typeId)) {
      _hive.registerAdapters();
    }
  });

  static Future<void> _initializeForApp(HiveInterface hive) =>
      hive.initFlutter('radius');

  Future<Box<BountyCM>> get bountiesBox => _open(_bountiesBoxKey);

  Future<Box<ClaimCM>> get claimsBox => _open(_claimsBoxKey);

  /// Small user preferences by name: whether onboarding was seen, and the
  /// like. Not a cache, so clearCaches leaves it alone.
  Future<Box<Object?>> get settingsBox => _open(_settingsBoxKey);

  /// One open per box, however many callers ask at once. Two concurrent
  /// openBox calls for the same name race inside Hive, and the loser throws.
  final Map<String, Future<Box<Object?>>> _opening = {};

  Future<Box<T>> _open<T>(String key) async {
    await _ready;
    if (_hive.isBoxOpen(key)) return _hive.box<T>(key);
    final pending = _opening.putIfAbsent(
      key,
      // A block, not an expression: whenComplete waits on a Future its
      // action returns, and remove would return the very future being
      // awaited.
      () => _hive.openBox<T>(key).whenComplete(() {
        _opening.remove(key);
      }),
    );
    return (await pending) as Box<T>;
  }

  Future<void> clearCaches() async {
    await (await bountiesBox).clear();
    await (await claimsBox).clear();
  }

  Future<void> close() async {
    await _ready;
    await _hive.close();
  }
}
