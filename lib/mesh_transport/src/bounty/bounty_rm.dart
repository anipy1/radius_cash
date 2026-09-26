import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// A bounty as it travels: one signed record, republished whole on every
/// change.
///
/// Public and self-contained. Anyone in range reads it, anyone can forward
/// it, and the signature is what stops anyone but the author from changing
/// it: a revision is only a revision if the same key signed it. The author
/// is named twice, by the peer id that sealed messages are addressed to and
/// by the signing key that proves the record, and the reader pins the two
/// together the first time it sees a bounty id.
///
/// Layout, big-endian, signature over everything before it:
///
///   [ver:1][id:8][author:8][signingKey:32][nostrKey:32][createdAt:4]
///   [expiresAt:4][updatedAt:4][amountCents:4][status:1][claimant:8]
///   [titleLen:1][title][detailsLen:2][details][geohashLen:1][geohash]
///   [signature:64]
///
/// nostrKey is where the author can be reached over the internet, signed
/// along with everything else so a relayed listing cannot point claims at
/// somebody else. Version 1 records, without it, still decode; the key is
/// then empty and a claim waits for the phones to meet.
///
/// The geohash is where the poster was, to five characters or so: coarse
/// on purpose, enough for a listing to be found by area and no more. Empty
/// when the poster did not share one.
class BountyRM {
  const BountyRM({
    required this.version,
    required this.id,
    required this.authorPeerId,
    required this.authorSigningKey,
    required this.authorNostrKey,
    required this.createdAt,
    required this.expiresAt,
    required this.updatedAt,
    required this.amountCents,
    required this.status,
    required this.claimantPeerId,
    required this.title,
    required this.details,
    required this.geohash,
    required this.signature,
  });

  static const currentVersion = 2;
  static const versionWithoutNostrKey = 1;

  static const statusOpen = 1;
  static const statusClaimed = 2;
  static const statusDone = 3;
  static const statusPaid = 4;
  static const statusCancelled = 5;

  /// UTF-8 bytes, not characters. Long enough for a sentence, short enough
  /// that a record stays a handful of fragments.
  static const maxTitleBytes = 100;
  static const maxDetailsBytes = 500;
  static const maxGeohashBytes = 12;

  static const idLength = 8;
  static const peerIdLength = 8;
  static const signingKeyLength = 32;
  static const nostrKeyLength = 32;
  static const signatureLength = 64;
  static const _fixedLength =
      1 +
      idLength +
      peerIdLength +
      signingKeyLength +
      4 * 4 +
      1 +
      peerIdLength +
      1 +
      2 +
      1;

  final int version;

  /// 16 hex characters. Random at creation, constant across revisions.
  final String id;

  /// 16 hex characters, the peer id claims are sent to.
  final String authorPeerId;
  final Uint8List authorSigningKey;

  /// 32 bytes, or empty on a version 1 record.
  final Uint8List authorNostrKey;

  String get authorNostrKeyHex =>
      authorNostrKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Unix seconds.
  final int createdAt;
  final int expiresAt;

  /// Unix seconds. A revision is only accepted if this is newer.
  final int updatedAt;
  final int amountCents;
  final int status;

  /// 16 hex characters, or null while nobody has been accepted.
  final String? claimantPeerId;
  final String title;
  final String details;

  /// Where the poster was, as a coarse cell, or empty.
  final String geohash;
  final Uint8List signature;

  static final _ed25519 = Ed25519();

  /// Builds and signs a record with [signingKeyPair], whose public key must
  /// be [signingPublicKey].
  static Future<BountyRM> sign({
    required String id,
    required String authorPeerId,
    required SimpleKeyPair signingKeyPair,
    required Uint8List signingPublicKey,
    required int createdAt,
    required int expiresAt,
    required int updatedAt,
    required int amountCents,
    required int status,
    required String? claimantPeerId,
    required String title,
    required String details,
    String geohash = '',
    Uint8List? nostrPublicKey,
  }) async {
    final unsigned = BountyRM(
      version: currentVersion,
      id: id,
      authorPeerId: authorPeerId,
      authorSigningKey: signingPublicKey,
      authorNostrKey: nostrPublicKey ?? Uint8List(0),
      createdAt: createdAt,
      expiresAt: expiresAt,
      updatedAt: updatedAt,
      amountCents: amountCents,
      status: status,
      claimantPeerId: claimantPeerId,
      title: title,
      details: details,
      geohash: geohash,
      signature: Uint8List(signatureLength),
    );
    final body = unsigned._encodeUnsigned();
    final sig = await _ed25519.sign(body, keyPair: signingKeyPair);
    return unsigned.copyWith(signature: Uint8List.fromList(sig.bytes));
  }

  /// A revision of this record by the same author, re-signed.
  Future<BountyRM> revise({
    required SimpleKeyPair signingKeyPair,
    required int updatedAt,
    int? status,
    String? claimantPeerId,
    bool clearClaimant = false,
  }) => sign(
    id: id,
    authorPeerId: authorPeerId,
    signingKeyPair: signingKeyPair,
    signingPublicKey: authorSigningKey,
    nostrPublicKey: authorNostrKey.isEmpty ? null : authorNostrKey,
    createdAt: createdAt,
    expiresAt: expiresAt,
    updatedAt: updatedAt,
    amountCents: amountCents,
    status: status ?? this.status,
    claimantPeerId: clearClaimant
        ? null
        : (claimantPeerId ?? this.claimantPeerId),
    title: title,
    details: details,
    geohash: geohash,
  );

  /// True when [signature] was made over this record by [authorSigningKey].
  Future<bool> verify() async {
    if (signature.length != signatureLength) return false;
    if (authorSigningKey.length != signingKeyLength) return false;
    try {
      return await _ed25519.verify(
        _encodeUnsigned(),
        signature: Signature(
          signature,
          publicKey: SimplePublicKey(
            authorSigningKey,
            type: KeyPairType.ed25519,
          ),
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Uint8List encode() {
    final body = _encodeUnsigned();
    return Uint8List(body.length + signatureLength)
      ..setRange(0, body.length, body)
      ..setRange(body.length, body.length + signatureLength, signature);
  }

  Uint8List _encodeUnsigned() {
    final titleBytes = utf8.encode(title);
    final detailsBytes = utf8.encode(details);
    final geohashBytes = utf8.encode(geohash);
    if (geohashBytes.length > maxGeohashBytes) {
      throw ArgumentError('geohash is ${geohashBytes.length}B, max 12');
    }
    if (titleBytes.length > maxTitleBytes) {
      throw ArgumentError('title is ${titleBytes.length}B, max $maxTitleBytes');
    }
    if (detailsBytes.length > maxDetailsBytes) {
      throw ArgumentError(
        'details is ${detailsBytes.length}B, max $maxDetailsBytes',
      );
    }
    // A version 2 record always carries a key; an empty one means the
    // author has none to share, and that is written as 32 zero bytes.
    final nostrLength = version >= currentVersion ? nostrKeyLength : 0;
    final nostrBytes = authorNostrKey.length == nostrKeyLength
        ? authorNostrKey
        : Uint8List(nostrKeyLength);
    final out = Uint8List(
      _fixedLength +
          nostrLength +
          titleBytes.length +
          detailsBytes.length +
          geohashBytes.length,
    );
    final view = ByteData.view(out.buffer);
    var o = 0;
    out[o++] = version;
    o = _putHex(out, o, id, idLength);
    o = _putHex(out, o, authorPeerId, peerIdLength);
    out.setRange(o, o + signingKeyLength, authorSigningKey);
    o += signingKeyLength;
    if (nostrLength > 0) {
      out.setRange(o, o + nostrKeyLength, nostrBytes);
      o += nostrKeyLength;
    }
    view.setUint32(o, createdAt, Endian.big);
    view.setUint32(o + 4, expiresAt, Endian.big);
    view.setUint32(o + 8, updatedAt, Endian.big);
    view.setUint32(o + 12, amountCents, Endian.big);
    o += 16;
    out[o++] = status;
    o = _putHex(
      out,
      o,
      claimantPeerId ?? '0' * (peerIdLength * 2),
      peerIdLength,
    );
    out[o++] = titleBytes.length;
    out.setRange(o, o + titleBytes.length, titleBytes);
    o += titleBytes.length;
    view.setUint16(o, detailsBytes.length, Endian.big);
    o += 2;
    out.setRange(o, o + detailsBytes.length, detailsBytes);
    o += detailsBytes.length;
    out[o++] = geohashBytes.length;
    out.setRange(o, o + geohashBytes.length, geohashBytes);
    return out;
  }

  /// Null when the bytes are not a record this build can read. A signature
  /// is not checked here; call [verify].
  static BountyRM? decode(Uint8List bytes) {
    if (bytes.length < _fixedLength + signatureLength) return null;
    final version = bytes[0];
    if (version != currentVersion && version != versionWithoutNostrKey) {
      return null;
    }
    final nostrLength = version >= currentVersion ? nostrKeyLength : 0;
    if (bytes.length < _fixedLength + nostrLength + signatureLength) {
      return null;
    }
    final view = ByteData.view(bytes.buffer, bytes.offsetInBytes);
    var o = 1;
    final id = _hex(bytes, o, idLength);
    o += idLength;
    final author = _hex(bytes, o, peerIdLength);
    o += peerIdLength;
    final key = Uint8List.fromList(bytes.sublist(o, o + signingKeyLength));
    o += signingKeyLength;
    var nostrKey = Uint8List.fromList(bytes.sublist(o, o + nostrLength));
    o += nostrLength;
    // All zeros means none, on the wire and in the record.
    if (nostrKey.every((b) => b == 0)) nostrKey = Uint8List(0);
    final createdAt = view.getUint32(o, Endian.big);
    final expiresAt = view.getUint32(o + 4, Endian.big);
    final updatedAt = view.getUint32(o + 8, Endian.big);
    final amountCents = view.getUint32(o + 12, Endian.big);
    o += 16;
    final status = bytes[o++];
    final claimant = _hex(bytes, o, peerIdLength);
    o += peerIdLength;
    final titleLen = bytes[o++];
    if (titleLen > maxTitleBytes) return null;
    if (bytes.length < o + titleLen + 2) return null;
    final title = utf8.decode(
      bytes.sublist(o, o + titleLen),
      allowMalformed: true,
    );
    o += titleLen;
    final detailsLen = view.getUint16(o, Endian.big);
    o += 2;
    if (detailsLen > maxDetailsBytes) return null;
    if (bytes.length < o + detailsLen + 1 + signatureLength) return null;
    final details = utf8.decode(
      bytes.sublist(o, o + detailsLen),
      allowMalformed: true,
    );
    o += detailsLen;
    final geohashLen = bytes[o++];
    if (geohashLen > maxGeohashBytes) return null;
    if (bytes.length != o + geohashLen + signatureLength) return null;
    final geohash = utf8.decode(
      bytes.sublist(o, o + geohashLen),
      allowMalformed: true,
    );
    o += geohashLen;
    final signature = Uint8List.fromList(bytes.sublist(o, o + signatureLength));
    return BountyRM(
      version: version,
      id: id,
      authorPeerId: author,
      authorSigningKey: key,
      authorNostrKey: nostrKey,
      createdAt: createdAt,
      expiresAt: expiresAt,
      updatedAt: updatedAt,
      amountCents: amountCents,
      status: status,
      claimantPeerId: claimant == '0' * (peerIdLength * 2) ? null : claimant,
      title: title,
      details: details,
      geohash: geohash,
      signature: signature,
    );
  }

  BountyRM copyWith({Uint8List? signature}) => BountyRM(
    version: version,
    id: id,
    authorPeerId: authorPeerId,
    authorSigningKey: authorSigningKey,
    authorNostrKey: authorNostrKey,
    createdAt: createdAt,
    expiresAt: expiresAt,
    updatedAt: updatedAt,
    amountCents: amountCents,
    status: status,
    claimantPeerId: claimantPeerId,
    title: title,
    details: details,
    geohash: geohash,
    signature: signature ?? this.signature,
  );

  static int _putHex(Uint8List out, int offset, String hex, int length) {
    if (hex.length != length * 2) {
      throw ArgumentError('expected ${length * 2} hex characters: "$hex"');
    }
    for (var i = 0; i < length; i++) {
      out[offset + i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return offset + length;
  }

  static String _hex(Uint8List bytes, int offset, int length) {
    final out = StringBuffer();
    for (var i = 0; i < length; i++) {
      out.write(bytes[offset + i].toRadixString(16).padLeft(2, '0'));
    }
    return out.toString();
  }
}
