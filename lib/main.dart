import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'component_library/component_library.dart';
import 'domain_models/domain_models.dart';
import 'keep_alive/keep_alive.dart';
import 'l10n/l10n.dart';
import 'local_storage/local_storage.dart';
import 'location/location.dart';
import 'mesh_transport/mesh_transport.dart';
import 'notifications/notifications.dart';
import 'repositories/bounty_repository/bounty_repository.dart';
import 'repositories/identity_repository/identity_repository.dart';
import 'repositories/location_repository/location_repository.dart';
import 'repositories/mesh_repository/mesh_repository.dart';
import 'repositories/settings_repository/settings_repository.dart';
import 'routing/routing.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RadiusRoot());
}

/// Owns the one thing above the composition root: which generation of it is
/// alive. Forgetting an identity tears the whole graph down and builds a
/// new one, the same as a relaunch, by giving [RadiusApp] a new key. The
/// old state's dispose stops the radio, closes the relays and lets go of
/// the foreground service before the new one loads a fresh seed.
class RadiusRoot extends StatefulWidget {
  const RadiusRoot({super.key});

  @override
  State<RadiusRoot> createState() => _RadiusRootState();
}

class _RadiusRootState extends State<RadiusRoot> {
  int _generation = 0;

  @override
  Widget build(BuildContext context) => RadiusApp(
    key: ValueKey(_generation),
    onIdentityForgotten: () => setState(() => _generation++),
  );
}

/// The composition root. Everything is built here, once, by constructor, and
/// handed down; nothing looks anything up.
class RadiusApp extends StatefulWidget {
  const RadiusApp({required this.onIdentityForgotten, super.key});

  /// The user erased the seed. Everything built here is now about a phone
  /// that no longer exists and has to be rebuilt.
  final VoidCallback onIdentityForgotten;

  @override
  State<RadiusApp> createState() => _RadiusAppState();
}

class _RadiusAppState extends State<RadiusApp> {
  /// Public relays, used only to reach peers already met on the mesh.
  static final _relayUrls = [
    Uri.parse('wss://nos.lol'),
    Uri.parse('wss://relay.primal.net'),
    Uri.parse('wss://nostr.mom'),
    Uri.parse('wss://offchain.pub'),
  ];

  final _lightTheme = LightAppThemeData();
  final _darkTheme = DarkAppThemeData();

  final _seedVault = const SecureSeedVault();

  /// Starts Hive on first use, so nothing here has to be awaited.
  final _keyValueStorage = KeyValueStorage();
  late final _identityStore = IdentityStore(vault: _seedVault);

  /// Read from the keystore exactly once per launch. Both repositories are
  /// handed this same future, so they agree on who this node is without
  /// either one having to expose the seed to the other.
  late final Future<LoadedIdentity> _loadedIdentity = _identityStore
      .loadOrCreate();

  /// The one radio, shared by every repository that speaks to the mesh, the
  /// way the kit shares one API client. Constructing it wires listeners but
  /// does not touch Bluetooth until start(), so building it off the identity
  /// future is safe.
  late final Future<MeshLink> _link = _loadedIdentity.then(
    (loaded) => MeshLink(identity: loaded.identity, source: loaded.source),
  );

  /// One relay pool, shared by the private-message bridge and the public
  /// board, authenticated with the Nostr key derived from the same seed.
  late final Future<RelayTransport> _relays = _loadedIdentity.then(
    (loaded) async => RelayPool.forUrls(
      _relayUrls,
      secretKey: (await NostrIdentity.fromSeed(
        loaded.identity.seed,
      )).privateKeyHex,
    ),
  );

  final _locationRepository = const LocationRepository(
    source: GeolocatorSource(),
  );

  late final _identityRepository = IdentityRepository(
    loadedIdentity: _loadedIdentity,
    keyValueStorage: _keyValueStorage,
    identityStore: _identityStore,
  );
  late final _settingsRepository = SettingsRepository(
    keyValueStorage: _keyValueStorage,
  );
  late final _meshRepository = MeshRepository(
    link: _link,
    relays: _relays,
    keepAlive: const PlatformKeepAlive(),
  );
  late final _bountyRepository = BountyRepository(
    link: _link,
    relays: _relays,
    keyValueStorage: _keyValueStorage,
  );

  /// Strings for alerts, which are built outside any widget and so have no
  /// BuildContext to ask. The device locale, falling back to the first
  /// supported one.
  AppLocalizations _strings() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    try {
      return lookupAppLocalizations(locale);
    } on FlutterError {
      return lookupAppLocalizations(AppLocalizations.supportedLocales.first);
    }
  }

  String _formatAmount(int cents) => NumberFormat.currency(
    locale: WidgetsBinding.instance.platformDispatcher.locale.toString(),
    symbol: '€',
    decimalDigits: cents % 100 == 0 ? 0 : 2,
  ).format(cents / 100);

  late final _localNotifier = LocalNotifier(
    channelName: _strings().notificationChannelName,
    channelDescription: _strings().notificationChannelDescription,
  );

  late final _bountyNotifier = BountyNotifier(
    bountyRepository: _bountyRepository,
    identityRepository: _identityRepository,
    notifier: _localNotifier,
    strings: _strings,
    isInForeground: () => _inForeground,
    formatAmount: _formatAmount,
    routeFor: (id) => RoutePaths.bountyDetail(id: id),
  );

  bool _inForeground = true;
  StreamSubscription<String>? _opened;

  late final _router = buildRouter(
    identityRepository: _identityRepository,
    meshRepository: _meshRepository,
    bountyRepository: _bountyRepository,
    locationRepository: _locationRepository,
    settingsRepository: _settingsRepository,
    onIdentityForgotten: widget.onIdentityForgotten,
  );

  /// Coming back to the foreground is the one lifecycle moment worth
  /// reacting to. Leaving needs nothing: the platform side keeps the radio up.
  late final _lifecycle = AppLifecycleListener(
    onResume: _onResumed,
    onStateChange: (state) =>
        _inForeground = state == AppLifecycleState.resumed,
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // built on first touch
    unawaited(_startNotifications());
  }

  Future<void> _startNotifications() async {
    try {
      await _localNotifier.initialize();
    } catch (_) {
      // No tray on this host. Everything else works without one.
      return;
    }
    _bountyNotifier.start();
    _opened = _localNotifier.opened.listen(_router.push);
    final launched = await _localNotifier.launchRoute();
    if (launched != null) unawaited(_router.push(launched));
  }

  void _onResumed() {
    unawaited(_meshRepository.resume().catchError((Object _) {}));
    unawaited(_bountyRepository.resume().catchError((Object _) {}));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_opened?.cancel());
    unawaited(_bountyNotifier.dispose().then((_) => _localNotifier.dispose()));
    // Bounties first: the mesh repository disposes the link they listen to.
    unawaited(_settingsRepository.dispose());
    unawaited(
      _bountyRepository.dispose().then((_) => _meshRepository.dispose()),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppTheme(
    lightTheme: _lightTheme,
    darkTheme: _darkTheme,
    child: StreamBuilder<DarkModePreference>(
      stream: _settingsRepository.getDarkModePreference(),
      builder: (context, snapshot) => MaterialApp.router(
        theme: _lightTheme.materialThemeData,
        darkTheme: _darkTheme.materialThemeData,
        // The Contra kit is drawn for light, so light until the user says
        // otherwise on the settings screen.
        themeMode: switch (snapshot.data) {
          DarkModePreference.alwaysDark => ThemeMode.dark,
          DarkModePreference.useSystemSettings => ThemeMode.system,
          DarkModePreference.alwaysLight || null => ThemeMode.light,
        },
        routerConfig: _router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      ),
    ),
  );
}
