import 'dart:convert';
import 'dart:typed_data';

/// What one party says to the other about a bounty, privately.
///
/// Travels inside a Noise session, so the sender is whoever the session was
/// authenticated to and the record needs no signature of its own. Small on
/// purpose: it fits in one sealed frame with room for a short note.
///
///   [kind:1][bountyId:8][sentAt:4][noteLen:1][note]
class BountyMessageRM {
  const BountyMessageRM({
    required this.kind,
    required this.bountyId,
    required this.sentAt,
    required this.note,
  });

  /// I would like to do this.
  static const kindClaim = 1;

  /// You are the one doing this.
  static const kindAccept = 2;

  /// Somebody else is, or nobody is.
  static const kindDecline = 3;

  /// I have finished.
  static const kindDone = 4;

  /// The poster's phone got the claim. Sent by the app, not the person: it
  /// says "delivered", never "yes". A claimant otherwise cannot tell a poster
  /// who is thinking from a phone that is off.
  static const kindReceived = 5;

  /// The claimant takes the offer back, for instance before erasing the
  /// identity that made it. A poster who had accepted them reopens.
  static const kindWithdraw = 6;

  static const maxNoteBytes = 120;
  static const _idLength = 8;
  static const _fixedLength = 1 + _idLength + 4 + 1;

  final int kind;
  final String bountyId;

  /// Unix seconds.
  final int sentAt;
  final String note;

  Uint8List encode() {
    final noteBytes = utf8.encode(note);
    if (noteBytes.length > maxNoteBytes) {
      throw ArgumentError('note is ${noteBytes.length}B, max $maxNoteBytes');
    }
    if (bountyId.length != _idLength * 2) {
      throw ArgumentError('a bounty id is ${_idLength * 2} hex characters');
    }
    final out = Uint8List(_fixedLength + noteBytes.length);
    final view = ByteData.view(out.buffer);
    out[0] = kind;
    for (var i = 0; i < _idLength; i++) {
      out[1 + i] = int.parse(bountyId.substring(i * 2, i * 2 + 2), radix: 16);
    }
    view.setUint32(1 + _idLength, sentAt, Endian.big);
    out[1 + _idLength + 4] = noteBytes.length;
    out.setRange(_fixedLength, out.length, noteBytes);
    return out;
  }

  static BountyMessageRM? decode(Uint8List bytes) {
    if (bytes.length < _fixedLength) return null;
    final kind = bytes[0];
    if (kind < kindClaim || kind > kindWithdraw) return null;
    final view = ByteData.view(bytes.buffer, bytes.offsetInBytes);
    final id = StringBuffer();
    for (var i = 0; i < _idLength; i++) {
      id.write(bytes[1 + i].toRadixString(16).padLeft(2, '0'));
    }
    final sentAt = view.getUint32(1 + _idLength, Endian.big);
    final noteLen = bytes[1 + _idLength + 4];
    if (bytes.length != _fixedLength + noteLen) return null;
    return BountyMessageRM(
      kind: kind,
      bountyId: id.toString(),
      sentAt: sentAt,
      note: utf8.decode(bytes.sublist(_fixedLength), allowMalformed: true),
    );
  }
}
