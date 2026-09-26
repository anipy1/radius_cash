import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// One phone's word that it heard a completion on the radio.
///
/// Standalone on purpose. A witness is not a field inside the bounty: anyone
/// holding these 157 bytes can check them without holding anything else, and
/// that is the entire value of the feature. So the record carries both of the
/// witness's public keys and binds them together itself.
///
/// Layout, big-endian, signature over everything before it:
///
///   [ver:1][bountyId:8][claimant:8][witnessPeer:8][witnessNoiseKey:32]
///   [witnessSigningKey:32][at:4][sig:64]
///   = 157 bytes
///
/// Verifying is two checks, and both matter:
///
/// 1. Ed25519 over the body with [witnessSigningKey], the same scheme
///    [BountyRM] uses. This proves a key signed it.
/// 2. [witnessPeerId] is the first 8 bytes of SHA-256 of [witnessNoiseKey].
///    This proves *which peer* that key belongs to.
///
/// The second check is why the noise key is here at all. A mesh peer id is
/// SHA-256 of the X25519 noise key, not of the Ed25519 signing key -- see
/// NodeIdentity.fromSeed, where the fingerprint is taken over noisePublicKey.
/// The two keys come off different HKDF info strings on the same seed, so
/// hashing the signing key would produce something that is not a peer id and
/// could not be compared against a bounty's author or claimant. Carrying the
/// noise key costs 32 bytes and one extra BLE fragment, and buys a record a
/// stranger can verify end to end.
class WitnessRM {
  const WitnessRM({
    required this.version,
    required this.bountyId,
    required this.claimantPeerId,
    required this.witnessPeerId,
    required this.witnessNoiseKey,
    required this.witnessSigningKey,
    required this.at,
    required this.signature,
  });

  static const currentVersion = 1;

  static const idLength = 8;
  static const peerIdLength = 8;
  static const noiseKeyLength = 32;
  static const signingKeyLength = 32;
  static const signatureLength = 64;

  /// Every field is fixed width, so a record is always exactly this long.
  static const recordLength =
      1 +
      idLength +
      peerIdLength +
      peerIdLength +
      noiseKeyLength +
      signingKeyLength +
      4 +
      signatureLength;

  final int version;

  /// 16 hex characters, the bounty this is about.
  final String bountyId;

  /// 16 hex characters, whoever said they finished it.
  final String claimantPeerId;

  /// 16 hex characters, the phone that heard them say so.
  final String witnessPeerId;

  /// The X25519 static key [witnessPeerId] is derived from.
  final Uint8List witnessNoiseKey;

  /// The Ed25519 key that made [signature].
  final Uint8List witnessSigningKey;

  /// Unix seconds.
  final int at;

  final Uint8List signature;

  static final _ed25519 = Ed25519();

  /// Builds and signs a record with [signingKeyPair], whose public key must
  /// be [signingPublicKey], for the node whose noise key is [noisePublicKey].
  static Future<WitnessRM> sign({
    required String bountyId,
    required String claimantPeerId,
    required String witnessPeerId,
    required SimpleKeyPair signingKeyPair,
    required Uint8List signingPublicKey,
    required Uint8List noisePublicKey,
    required int at,
  }) async {
    final unsigned = WitnessRM(
      version: currentVersion,
      bountyId: bountyId,
      claimantPeerId: claimantPeerId,
      witnessPeerId: witnessPeerId,
      witnessNoiseKey: noisePublicKey,
      witnessSigningKey: signingPublicKey,
      at: at,
      signature: Uint8List(signatureLength),
    );
    final body = unsigned._encodeUnsigned();
    final sig = await _ed25519.sign(body, keyPair: signingKeyPair);
    return unsigned.copyWith(signature: Uint8List.fromList(sig.bytes));
  }

  /// True when the signature holds *and* the claimed peer id really is the
  /// one this noise key produces. Either half failing makes the record
  /// worthless, so neither is optional and there is no way to ask for one.
  Future<bool> verify() async {
    if (signature.length != signatureLength) return false;
    if (witnessSigningKey.length != signingKeyLength) return false;
    if (witnessNoiseKey.length != noiseKeyLength) return false;
    if (!await bindsToItsPeerId()) return false;
    try {
      return await _ed25519.verify(
        _encodeUnsigned(),
        signature: Signature(
          signature,
          publicKey: SimplePublicKey(
            witnessSigningKey,
            type: KeyPairType.ed25519,
          ),
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Whether [witnessPeerId] is what [witnessNoiseKey] hashes to.
  ///
  /// Exactly the construction in NodeIdentity: SHA-256 of the noise static
  /// key, first 8 bytes, hex. A record that fails this names a peer it cannot
  /// speak for, whoever signed it.
  Future<bool> bindsToItsPeerId() async {
    if (witnessNoiseKey.length != noiseKeyLength) return false;
    final digest = await Sha256().hash(witnessNoiseKey);
    return _bytesToHex(digest.bytes.sublist(0, peerIdLength)) == witnessPeerId;
  }

  Uint8List encode() {
    final body = _encodeUnsigned();
    return Uint8List(body.length + signatureLength)
      ..setRange(0, body.length, body)
      ..setRange(body.length, body.length + signatureLength, signature);
  }

  Uint8List _encodeUnsigned() {
    if (witnessNoiseKey.length != noiseKeyLength) {
      throw ArgumentError('noise key is ${witnessNoiseKey.length}B, need 32');
    }
    if (witnessSigningKey.length != signingKeyLength) {
      throw ArgumentError(
        'signing key is ${witnessSigningKey.length}B, need 32',
      );
    }
    final out = Uint8List(recordLength - signatureLength);
    final view = ByteData.view(out.buffer);
    var o = 0;
    out[o++] = version;
    o = _putHex(out, o, bountyId, idLength);
    o = _putHex(out, o, claimantPeerId, peerIdLength);
    o = _putHex(out, o, witnessPeerId, peerIdLength);
    out.setRange(o, o + noiseKeyLength, witnessNoiseKey);
    o += noiseKeyLength;
    out.setRange(o, o + signingKeyLength, witnessSigningKey);
    o += signingKeyLength;
    view.setUint32(o, at, Endian.big);
    return out;
  }

  /// Null when the bytes are not a record this build can read. Neither the
  /// signature nor the peer binding is checked here; call [verify].
  static WitnessRM? decode(Uint8List bytes) {
    if (bytes.length != recordLength) return null;
    if (bytes[0] != currentVersion) return null;
    final view = ByteData.view(bytes.buffer, bytes.offsetInBytes);
    var o = 1;
    final bountyId = _hex(bytes, o, idLength);
    o += idLength;
    final claimant = _hex(bytes, o, peerIdLength);
    o += peerIdLength;
    final witness = _hex(bytes, o, peerIdLength);
    o += peerIdLength;
    final noiseKey = Uint8List.fromList(bytes.sublist(o, o + noiseKeyLength));
    o += noiseKeyLength;
    final signingKey = Uint8List.fromList(
      bytes.sublist(o, o + signingKeyLength),
    );
    o += signingKeyLength;
    final at = view.getUint32(o, Endian.big);
    o += 4;
    final signature = Uint8List.fromList(bytes.sublist(o, o + signatureLength));
    return WitnessRM(
      version: bytes[0],
      bountyId: bountyId,
      claimantPeerId: claimant,
      witnessPeerId: witness,
      witnessNoiseKey: noiseKey,
      witnessSigningKey: signingKey,
      at: at,
      signature: signature,
    );
  }

  WitnessRM copyWith({Uint8List? signature}) => WitnessRM(
    version: version,
    bountyId: bountyId,
    claimantPeerId: claimantPeerId,
    witnessPeerId: witnessPeerId,
    witnessNoiseKey: witnessNoiseKey,
    witnessSigningKey: witnessSigningKey,
    at: at,
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

  static String _bytesToHex(List<int> bytes) {
    final out = StringBuffer();
    for (final b in bytes) {
      out.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return out.toString();
  }
}
