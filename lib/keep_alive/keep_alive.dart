/// Keeps the process alive while the radio listens, on platforms that would
/// otherwise wind it down. Plays the same role for the mesh repository that
/// lib/location plays for the location one: a thin platform seam.
library;

export 'src/keep_alive.dart' show KeepAlive, NoKeepAlive, PlatformKeepAlive;
