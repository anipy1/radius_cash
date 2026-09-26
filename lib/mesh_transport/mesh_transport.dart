/// The radio and everything that rides on it.
///
/// This folder is the app's "remote API": a BLE mesh with Noise sessions and a
/// Nostr relay path for when the radio cannot reach. It is pure Dart apart from
/// the Bluetooth plugin, knows nothing about bounties or screens, and is only
/// ever spoken to through repositories.
library;

// The adapter state, so a mapper can read MeshLink.state without importing
// the Bluetooth plugin itself.
export 'package:bluetooth_low_energy/bluetooth_low_energy.dart'
    show BluetoothLowEnergyState;

export 'src/ble/frame.dart' show Frame, Announce, SealedEnvelope;
export 'src/ble/mesh_link.dart'
    show MeshLink, InboundMessage, ObservedPeer, LogLevel, LogLine;
export 'src/ble/sealed_payload.dart' show SealedKind, SealedPayload;
export 'src/bounty/bounty_message_rm.dart' show BountyMessageRM;
export 'src/bounty/bounty_rm.dart' show BountyRM;
export 'src/identity/identity_store.dart'
    show IdentityStore, IdentitySource, LoadedIdentity, SeedVault;
export 'src/identity/node_identity.dart' show NodeIdentity;
export 'src/identity/nostr_identity.dart' show NostrIdentity;
export 'src/nostr/nostr_board.dart' show NostrBoard;
export 'src/nostr/nostr_bridge.dart' show NostrBridge, NostrInbound;
export 'src/nostr/relay_client.dart' show RelayClient, PublishResult;
export 'src/nostr/relay_pool.dart' show RelayPool;
export 'src/nostr/relay_transport.dart' show RelayTransport;
