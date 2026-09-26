import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/mesh_transport/mesh_transport.dart';

extension IdentitySourceToDomain on IdentitySource {
  IdentityOrigin toDomainModel() => switch (this) {
    IdentitySource.restored => IdentityOrigin.restored,
    IdentitySource.created => IdentityOrigin.created,
    IdentitySource.replaced => IdentityOrigin.replaced,
  };
}

extension LoadedIdentityToDomain on LoadedIdentity {
  Identity toDomainModel({required NostrIdentity nostr}) => Identity(
    peerId: identity.peerId,
    shortId: identity.shortId,
    npub: nostr.npub,
    origin: source.toDomainModel(),
  );
}
