/// Where the phone is, from its own sensors. Plays the same role for the
/// location repository that mesh_transport plays for the mesh one.
library;

export 'src/location_source.dart'
    show
        GeolocatorSource,
        LocationFailure,
        LocationSource,
        LocationSourceException;
