import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/location/location.dart';

/// Where this phone is, as a coarse cell.
///
/// Nothing is tracked. A fix is taken when asked for, rounded to a geohash
/// of [Geohash.defaultPrecision], and the exact coordinates go no further
/// than this method.
class LocationRepository {
  const LocationRepository({required LocationSource source}) : _source = source;

  final LocationSource _source;

  Future<Geohash> currentGeohash({
    int precision = Geohash.defaultPrecision,
  }) async {
    try {
      final p = await _source.currentPosition();
      return Geohash.encode(p.latitude, p.longitude, precision: precision);
    } on LocationSourceException catch (e) {
      throw switch (e.why) {
        LocationFailure.denied => LocationPermissionDeniedException(),
        LocationFailure.unavailable => LocationUnavailableException(),
      };
    } catch (_) {
      throw LocationUnavailableException();
    }
  }
}
