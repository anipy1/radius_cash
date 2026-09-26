import 'package:geolocator/geolocator.dart';

/// Why a fix could not be had.
enum LocationFailure { denied, unavailable }

class LocationSourceException implements Exception {
  const LocationSourceException(this.why);

  final LocationFailure why;
}

/// One position fix, asking for permission on the way if needed.
///
/// Thin over the plugin on purpose, so a repository test can hand in a fake
/// without touching platform channels.
abstract class LocationSource {
  Future<({double latitude, double longitude})> currentPosition();
}

class GeolocatorSource implements LocationSource {
  const GeolocatorSource({this.timeout = const Duration(seconds: 15)});

  final Duration timeout;

  @override
  Future<({double latitude, double longitude})> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationSourceException(LocationFailure.unavailable);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationSourceException(LocationFailure.denied);
    }
    try {
      // Low accuracy is plenty: the result is rounded to a 5 km cell, and a
      // coarse fix arrives in seconds where a fine one can take a minute
      // indoors.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: timeout,
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      throw const LocationSourceException(LocationFailure.unavailable);
    }
  }
}
