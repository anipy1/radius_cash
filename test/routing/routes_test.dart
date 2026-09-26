import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:radius/repositories/bounty_repository/bounty_repository.dart';
import 'package:radius/repositories/identity_repository/identity_repository.dart';
import 'package:radius/repositories/location_repository/location_repository.dart';
import 'package:radius/repositories/mesh_repository/mesh_repository.dart';
import 'package:radius/repositories/settings_repository/settings_repository.dart';
import 'package:radius/routing/routing.dart';

class MockIdentityRepository extends Mock implements IdentityRepository {}

class MockMeshRepository extends Mock implements MeshRepository {}

class MockBountyRepository extends Mock implements BountyRepository {}

class MockLocationRepository extends Mock implements LocationRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  group('Routes:', () {
    final router = buildRouter(
      identityRepository: MockIdentityRepository(),
      meshRepository: MockMeshRepository(),
      bountyRepository: MockBountyRepository(),
      locationRepository: MockLocationRepository(),
      settingsRepository: MockSettingsRepository(),
      onIdentityForgotten: () {},
    );

    RouteBase nameFor(String location) =>
        router.configuration.findMatch(Uri.parse(location)).matches.last.route;

    String? routeName(String location) => (nameFor(location) as GoRoute).name;

    test(
      'When pushing the create path, it is the create screen, not a detail',
      () {
        // '/bounties/new' also fits '/bounties/:id'; order decides.
        expect(routeName(RoutePaths.bountyCreate), 'bounty-create');
      },
    );

    test('When pushing a bounty id, it is the detail screen', () {
      expect(
        routeName(RoutePaths.bountyDetail(id: '0123456789abcdef')),
        'bounty-detail',
      );
    });

    test('When at the root, it is the feed', () {
      expect(routeName(RoutePaths.home), 'bounty-feed');
    });

    test('When at the peers path, it is the peers screen', () {
      expect(routeName(RoutePaths.peers), 'peers');
    });

    test('When at the settings path, it is the settings screen', () {
      expect(routeName(RoutePaths.settings), 'settings');
    });

    test('When at the welcome path, it is onboarding', () {
      expect(routeName(RoutePaths.onboarding), 'identity-onboarding');
    });
  });
}
