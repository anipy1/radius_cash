import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:radius/component_library/component_library.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/l10n/l10n.dart';
import 'package:radius/repositories/bounty_repository/bounty_repository.dart';
import 'package:radius/repositories/location_repository/location_repository.dart';
import 'package:radius/repositories/mesh_repository/mesh_repository.dart';

import 'bounty_card.dart';
import 'bounty_feed_bloc.dart';
import 'mesh_status_strip.dart';

/// The notice board, and the screen that switches the radio on.
class BountyFeedScreen extends StatelessWidget {
  const BountyFeedScreen({
    required this.bountyRepository,
    required this.meshRepository,
    required this.locationRepository,
    required this.onBountySelected,
    required this.onPostBountyTapped,
    required this.onPeersTapped,
    required this.onSettingsTapped,
    super.key,
  });

  final BountyRepository bountyRepository;
  final MeshRepository meshRepository;
  final LocationRepository locationRepository;
  final ValueChanged<String> onBountySelected;
  final VoidCallback onPostBountyTapped;
  final VoidCallback onPeersTapped;
  final VoidCallback onSettingsTapped;

  @override
  Widget build(BuildContext context) => BlocProvider<BountyFeedBloc>(
    create: (_) => BountyFeedBloc(
      bountyRepository: bountyRepository,
      meshRepository: meshRepository,
      locationRepository: locationRepository,
    )..add(const BountyFeedStarted()),
    child: BountyFeedView(
      onBountySelected: onBountySelected,
      onPostBountyTapped: onPostBountyTapped,
      onPeersTapped: onPeersTapped,
      onSettingsTapped: onSettingsTapped,
    ),
  );
}

@visibleForTesting
class BountyFeedView extends StatelessWidget {
  const BountyFeedView({
    required this.onBountySelected,
    required this.onPostBountyTapped,
    required this.onPeersTapped,
    required this.onSettingsTapped,
    super.key,
  });

  final ValueChanged<String> onBountySelected;
  final VoidCallback onPostBountyTapped;
  final VoidCallback onPeersTapped;
  final VoidCallback onSettingsTapped;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.of(context);
    return BlocBuilder<BountyFeedBloc, BountyFeedState>(
      builder: (context, state) {
        final bloc = context.read<BountyFeedBloc>();
        return Scaffold(
          appBar: ContraAppBar(
            title: l10n.bountyFeedAppBarTitle,
            actions: [
              ContraIconButton(
                icon: Icons.people_outline,
                semanticLabel: l10n.bountyFeedPeersButtonLabel,
                onPressed: onPeersTapped,
              ),
              const SizedBox(width: Spacing.small),
              ContraIconButton(
                icon: Icons.settings_outlined,
                semanticLabel: l10n.bountyFeedSettingsButtonLabel,
                onPressed: onSettingsTapped,
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  theme.screenMargin,
                  Spacing.medium,
                  theme.screenMargin,
                  Spacing.medium,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MeshStatusStrip(
                      meshStatus: state.meshStatus,
                      relayStatus: state.relayStatus,
                    ),
                    const SizedBox(height: Spacing.medium),
                    ContraSegmentedControl(
                      labels: [
                        l10n.bountyFeedSegmentNearby,
                        l10n.bountyFeedSegmentMine,
                        l10n.bountyFeedSegmentClaimed,
                      ],
                      selectedIndex: state.segment.index,
                      onSelected: (i) => bloc.add(
                        BountyFeedSegmentChanged(BountyFeedSegment.values[i]),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _Body(state: state, onBountySelected: onBountySelected),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: EdgeInsets.all(theme.screenMargin),
            child: ContraButton.primary(
              label: l10n.bountyFeedPostButtonLabel,
              icon: Icons.add,
              onPressed: onPostBountyTapped,
            ),
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.onBountySelected});

  static const _emptyPeepHeight = Spacing.xxxLarge * 3;

  final BountyFeedState state;
  final ValueChanged<String> onBountySelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.of(context);

    if (state.startStatus == MeshStartStatus.failed &&
        state.segment == BountyFeedSegment.nearby) {
      return ContraEmptyState(
        icon: Icons.bluetooth_disabled,
        title: l10n.bountyFeedMeshUnavailableTitle,
        body: switch (state.meshStatus.phase) {
          MeshPhase.unauthorized => l10n.bountyFeedMeshUnauthorizedBody,
          MeshPhase.unsupported => l10n.bountyFeedMeshUnsupportedBody,
          _ => l10n.bountyFeedMeshUnavailableBody,
        },
        actionLabel: l10n.bountyFeedRetryButtonLabel,
        onAction: () => context.read<BountyFeedBloc>().add(
          const BountyFeedRetryRequested(),
        ),
      );
    }

    if (state.cacheFailed && state.bounties.isEmpty) {
      return ContraEmptyState(
        icon: Icons.sd_storage_outlined,
        title: l10n.bountyFeedCacheFailedTitle,
        body: l10n.bountyFeedCacheFailedBody,
      );
    }

    final visible = state.visible;
    if (visible.isEmpty) {
      return switch (state.segment) {
        BountyFeedSegment.nearby => ContraEmptyState(
          icon: Icons.radar,
          illustration: const ContraPeep(
            asset: PeepAssets.standingArmsCrossed,
            height: _emptyPeepHeight,
          ),
          title: l10n.bountyFeedEmptyNearbyTitle,
          body: l10n.bountyFeedEmptyNearbyBody,
        ),
        BountyFeedSegment.mine => ContraEmptyState(
          icon: Icons.edit_note,
          illustration: const ContraPeep(
            asset: PeepAssets.sittingLaughing,
            height: _emptyPeepHeight,
          ),
          title: l10n.bountyFeedEmptyMineTitle,
          body: l10n.bountyFeedEmptyMineBody,
        ),
        BountyFeedSegment.claimed => ContraEmptyState(
          icon: Icons.front_hand_outlined,
          illustration: const ContraPeep(
            asset: PeepAssets.standingCasual,
            height: _emptyPeepHeight,
          ),
          title: l10n.bountyFeedEmptyClaimedTitle,
          body: l10n.bountyFeedEmptyClaimedBody,
        ),
      };
    }

    final now = DateTime.now();
    final myClaims = {
      for (final c in state.claims)
        if (c.isMine) c.bountyId: c.status,
    };
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        theme.screenMargin,
        0,
        theme.screenMargin,
        Spacing.medium,
      ),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.medium),
      itemBuilder: (context, i) => BountyCard(
        bounty: visible[i],
        now: now,
        myClaim: myClaims[visible[i].id],
        onTap: () => onBountySelected(visible[i].id),
      ),
    );
  }
}
