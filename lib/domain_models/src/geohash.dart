import 'package:equatable/equatable.dart';

/// A place, as a string that gets more precise the longer it is.
///
/// Each character narrows the cell by a factor of 32: four characters is a
/// city, five a district, six a few streets, eight a house. A listing
/// carries a coarse cell so people can find it by area; a phone never
/// publishes where exactly it is.
class Geohash extends Equatable {
  const Geohash(this.value);

  /// Encodes [latitude] and [longitude] to [precision] characters.
  factory Geohash.encode(
    double latitude,
    double longitude, {
    int precision = defaultPrecision,
  }) {
    var latMin = -90.0, latMax = 90.0, lonMin = -180.0, lonMax = 180.0;
    final out = StringBuffer();
    var bits = 0, value = 0, even = true;
    while (out.length < precision) {
      if (even) {
        final mid = (lonMin + lonMax) / 2;
        if (longitude >= mid) {
          value = (value << 1) | 1;
          lonMin = mid;
        } else {
          value = value << 1;
          lonMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (latitude >= mid) {
          value = (value << 1) | 1;
          latMin = mid;
        } else {
          value = value << 1;
          latMax = mid;
        }
      }
      even = !even;
      if (++bits == 5) {
        out.write(_alphabet[value]);
        bits = 0;
        value = 0;
      }
    }
    return Geohash(out.toString());
  }

  static const _alphabet = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// What a listing carries: about 5 km by 5 km.
  static const defaultPrecision = 5;

  /// What a reader subscribes to: about 40 km by 20 km, so a bounty on the
  /// other side of the city still shows.
  static const areaPrecision = 4;

  final String value;

  int get precision => value.length;

  /// This cell at a coarser precision, or itself if already coarser.
  Geohash truncate(int precision) =>
      precision >= value.length ? this : Geohash(value.substring(0, precision));

  /// Every prefix from one character up, coarsest first, so a listing can
  /// be tagged at every level and found by any of them.
  List<String> get prefixes => [
    for (var i = 1; i <= value.length; i++) value.substring(0, i),
  ];

  static bool isValid(String s) =>
      s.isNotEmpty && s.length <= 12 && s.split('').every(_alphabet.contains);

  @override
  List<Object?> get props => [value];
}
