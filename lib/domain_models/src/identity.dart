import 'package:equatable/equatable.dart';

/// How this node's identity was obtained at launch.
enum IdentityOrigin {
  /// Read back from the device's secure storage. The normal case.
  restored,

  /// Nothing was stored, so a new one was made. Expected exactly once.
  created,

  /// Something was stored but could not be read, so a new one was made. A
  /// silent change of who this node is, so it is worth telling the user.
  replaced,
}

/// Who this node is, as far as anyone else can tell.
class Identity extends Equatable {
  const Identity({
    required this.peerId,
    required this.shortId,
    required this.npub,
    required this.origin,
  });

  /// Sixteen hex characters. What other nodes address messages to.
  final String peerId;

  /// Four characters, what a human reads off a screen.
  final String shortId;

  /// The Nostr address peers can reach this node at over the internet.
  final String npub;

  final IdentityOrigin origin;

  @override
  List<Object?> get props => [peerId, shortId, npub, origin];
}
