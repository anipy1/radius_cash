/// The identity could not be loaded or created.
class IdentityLoadException implements Exception {}

/// The mesh could not start: no Bluetooth LE, permission refused, or the
/// platform failed underneath us.
class MeshUnavailableException implements Exception {}

/// A send was attempted while the mesh was not running.
class MeshNotRunningException implements Exception {}

/// The mesh was running but the message could not be handed to the radio.
class MeshSendException implements Exception {}

/// The relay path could not be brought up.
class RelayUnavailableException implements Exception {}

/// No bounty with that id is known here.
class BountyNotFoundException implements Exception {}

/// Only the author can do that to a bounty.
class NotBountyAuthorException implements Exception {}

/// The bounty is no longer open, so the action makes no sense.
class BountyClosedException implements Exception {}

/// A field is out of bounds: empty title, title or details too long, amount
/// not positive, expiry in the past.
class BountyValidationException implements Exception {}

/// The radio would not take the bounty frame.
class BountySendException implements Exception {}

/// The on-device cache could not be read or written.
class BountyCacheException implements Exception {}

/// You posted it; claim it and you would be paying yourself.
class CannotClaimOwnBountyException implements Exception {}

/// A preference could not be read or written on this device.
class PreferencesException implements Exception {}

/// The seed could not be erased, so the identity is still here.
class IdentityForgetException implements Exception {}

/// The user said no to location, or turned it off for the app.
class LocationPermissionDeniedException implements Exception {}

/// Location services are off, or no fix came in time.
class LocationUnavailableException implements Exception {}
