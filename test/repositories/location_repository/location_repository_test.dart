import 'package:flutter_test/flutter_test.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/location/location.dart';
import 'package:radius/repositories/location_repository/location_repository.dart';

class _FixedSource implements LocationSource {
  const _FixedSource(this.lat, this.lon);
  final double lat;
  final double lon;

  @override
  Future<({double latitude, double longitude})> currentPosition() async =>
      (latitude: lat, longitude: lon);
}

class _FailingSource implements LocationSource {
  const _FailingSource(this.why);
  final LocationFailure why;

  @override
  Future<({double latitude, double longitude})> currentPosition() =>
      throw LocationSourceException(why);
}

void main() {
  group('LocationRepository:', () {
    test('When a fix arrives, returns a five character cell', () async {
      final repository = const LocationRepository(
        source: _FixedSource(59.4370, 24.7536),
      );
      expect(await repository.currentGeohash(), const Geohash('ud9d5'));
    });

    test('When permission is denied, throws the domain exception', () {
      const repository = LocationRepository(
        source: _FailingSource(LocationFailure.denied),
      );
      expect(
        repository.currentGeohash(),
        throwsA(isA<LocationPermissionDeniedException>()),
      );
    });

    test('When no fix comes, throws unavailable', () {
      const repository = LocationRepository(
        source: _FailingSource(LocationFailure.unavailable),
      );
      expect(
        repository.currentGeohash(),
        throwsA(isA<LocationUnavailableException>()),
      );
    });
  });
}
