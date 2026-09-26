import 'package:equatable/equatable.dart';

/// Another node we know how to address.
class Peer extends Equatable {
  const Peer({
    required this.id,
    required this.label,
    required this.hasSecureSession,
    required this.reachableOnMesh,
    required this.reachableViaInternet,
  });

  final String id;

  /// The short label derived from [id], the one people say out loud.
  final String label;

  /// Whether a Noise session is established, so private messages can go now
  /// rather than after a handshake.
  final bool hasSecureSession;

  /// Whether the radio has a path to this peer right now.
  final bool reachableOnMesh;

  /// Whether we learnt this peer's Nostr address, so relays are a fallback.
  final bool reachableViaInternet;

  @override
  List<Object?> get props => [
    id,
    label,
    hasSecureSession,
    reachableOnMesh,
    reachableViaInternet,
  ];
}
