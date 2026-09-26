import 'package:flutter/widgets.dart';
import 'package:radius/demo/demo_mode.dart';
import 'package:go_router/go_router.dart';
import 'package:radius/features/bounty_create/bounty_create.dart';
import 'package:radius/features/bounty_detail/bounty_detail.dart';
import 'package:radius/features/bounty_feed/bounty_feed.dart';
import 'package:radius/features/identity_onboarding/identity_onboarding.dart';
import 'package:radius/features/peers/peers.dart';
import 'package:radius/features/settings/settings.dart';
import 'package:radius/repositories/bounty_repository/bounty_repository.dart';
import 'package:radius/repositories/identity_repository/identity_repository.dart';
import 'package:radius/repositories/location_repository/location_repository.dart';
import 'package:radius/repositories/mesh_repository/mesh_repository.dart';
import 'package:radius/repositories/settings_repository/settings_repository.dart';

/// Every path in one place, composed so the same source builds both the
/// pattern go_router matches and the concrete URL a callback pushes.
abstract class RoutePaths {
  static const home = '/';
  static const onboarding = '/welcome';
  static const peers = '/peers';
  static const settings = '/settings';
  static const bountyCreate = '/bounties/new';
  static const bountyIdParameter = 'id';
  static String bountyDetail({String? id}) =>
      '/bounties/${id ?? ':$bountyIdParameter'}';
}

/// The one place that knows every feature exists and how they hand off to
/// each other.
GoRouter buildRouter({
  required IdentityRepository identityRepository,
  required MeshRepository meshRepository,
  required BountyRepository bountyRepository,
  required LocationRepository locationRepository,
  required SettingsRepository settingsRepository,
  required VoidCallback onIdentityForgotten,
}) => GoRouter(
  initialLocation: RoutePaths.home,
  // First launch goes to the welcome screens and nowhere else; after
  // that the welcome path is never shown again. The repository remembers
  // the answer, so this is one disk read per app start.
  redirect: (context, state) async {
    // Validation session: start straight on the feed, no welcome screens.
    if (demoMode) {
      return state.matchedLocation == RoutePaths.onboarding
          ? RoutePaths.home
          : null;
    }
    final onboarded = await identityRepository.hasOnboarded();
    final atWelcome = state.matchedLocation == RoutePaths.onboarding;
    if (!onboarded && !atWelcome) return RoutePaths.onboarding;
    if (onboarded && atWelcome) return RoutePaths.home;
    return null;
  },
  routes: [
    GoRoute(
      path: RoutePaths.onboarding,
      name: 'identity-onboarding',
      builder: (context, _) => IdentityOnboardingScreen(
        identityRepository: identityRepository,
        onFinished: () => context.go(RoutePaths.home),
      ),
    ),
    GoRoute(
      path: RoutePaths.home,
      name: 'bounty-feed',
      builder: (context, _) => BountyFeedScreen(
        bountyRepository: bountyRepository,
        meshRepository: meshRepository,
        locationRepository: locationRepository,
        onPostBountyTapped: () => context.push(RoutePaths.bountyCreate),
        onBountySelected: (id) => context.push(RoutePaths.bountyDetail(id: id)),
        onPeersTapped: () => context.push(RoutePaths.peers),
        onSettingsTapped: () => context.push(RoutePaths.settings),
      ),
    ),
    GoRoute(
      path: RoutePaths.settings,
      name: 'settings',
      builder: (context, _) => SettingsScreen(
        settingsRepository: settingsRepository,
        identityRepository: identityRepository,
        meshRepository: meshRepository,
        bountyRepository: bountyRepository,
        onBackPressed: () => context.pop(),
        onIdentityForgotten: onIdentityForgotten,
      ),
    ),
    GoRoute(
      path: RoutePaths.peers,
      name: 'peers',
      builder: (context, _) => PeersScreen(
        meshRepository: meshRepository,
        identityRepository: identityRepository,
        onBackPressed: () => context.pop(),
      ),
    ),
    // Before the detail route on purpose: go_router matches in order and
    // '/bounties/new' would otherwise be a detail screen for the id "new".
    GoRoute(
      path: RoutePaths.bountyCreate,
      name: 'bounty-create',
      builder: (context, _) => BountyCreateScreen(
        bountyRepository: bountyRepository,
        locationRepository: locationRepository,
        onBountyPosted: (_) => context.pop(),
        onCancelled: () => context.pop(),
      ),
    ),
    GoRoute(
      path: RoutePaths.bountyDetail(),
      name: 'bounty-detail',
      builder: (context, state) => BountyDetailScreen(
        bountyId: state.pathParameters[RoutePaths.bountyIdParameter]!,
        bountyRepository: bountyRepository,
        onBackPressed: () => context.pop(),
      ),
    ),
  ],
);
