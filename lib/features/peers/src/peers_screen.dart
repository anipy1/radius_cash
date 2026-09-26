import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:radius/component_library/component_library.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/l10n/l10n.dart';
import 'package:radius/repositories/identity_repository/identity_repository.dart';
import 'package:radius/repositories/mesh_repository/mesh_repository.dart';

import 'peers_bloc.dart';

class PeersScreen extends StatelessWidget {
  const PeersScreen({
    required this.meshRepository,
    required this.identityRepository,
    required this.onBackPressed,
    super.key,
  });

  final MeshRepository meshRepository;
  final IdentityRepository identityRepository;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) => BlocProvider<PeersBloc>(
    create: (_) => PeersBloc(
      meshRepository: meshRepository,
      identityRepository: identityRepository,
    ),
    child: PeersView(onBackPressed: onBackPressed),
  );
}

@visibleForTesting
class PeersView extends StatelessWidget {
  const PeersView({required this.onBackPressed, super.key});

  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.of(context);
    return BlocBuilder<PeersBloc, PeersState>(
      builder: (context, state) => Scaffold(
        appBar: ContraAppBar(
          title: l10n.peersAppBarTitle,
          leading: Center(
            child: ContraIconButton(
              icon: Icons.arrow_back,
              semanticLabel: l10n.peersBackButtonLabel,
              onPressed: onBackPressed,
            ),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.all(theme.screenMargin),
          children: [
            _MeSection(state: state),
            const SizedBox(height: Spacing.large),
            Text(
              l10n.peersInRangeTitle(state.peers.length),
              style: theme.subtitleTextStyle,
            ),
            const SizedBox(height: Spacing.medium),
            if (state.peers.isEmpty)
              ContraEmptyState(
                icon: Icons.radar,
                illustration: const ContraPeep(
                  asset: PeepAssets.standingSmiling,
                  height: Spacing.xxxLarge * 2,
                ),
                title: l10n.peersEmptyTitle,
                body: switch (state.meshStatus.phase) {
                  MeshPhase.running => l10n.peersEmptyBodyRunning(
                    state.meshStatus.nearbyDeviceCount,
                  ),
                  _ => l10n.peersEmptyBodyStopped,
                },
              )
            else
              for (final peer in state.peers) ...[
                _PeerTile(peer: peer),
                const SizedBox(height: Spacing.small),
              ],
          ],
        ),
      ),
    );
  }
}

/// This phone, and the state of its two paths out.
class _MeSection extends StatelessWidget {
  const _MeSection({required this.state});

  final PeersState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.of(context);
    final identity = state.identity;
    final (meshLabel, meshTone) = switch (state.meshStatus.phase) {
      MeshPhase.running => (l10n.peersMeshRunning, Tone.success),
      MeshPhase.stopped => (l10n.peersMeshStopped, Tone.neutral),
      MeshPhase.waitingForBluetooth => (l10n.peersMeshWaiting, Tone.warning),
      MeshPhase.unauthorized => (l10n.peersMeshUnauthorized, Tone.danger),
      MeshPhase.unsupported => (l10n.peersMeshUnsupported, Tone.danger),
    };
    final (relayLabel, relayTone) = switch (state.relayStatus) {
      RelayStatus.connected => (l10n.peersRelayConnected, Tone.accent),
      RelayStatus.connecting => (l10n.peersRelayConnecting, Tone.warning),
      RelayStatus.stopped => (l10n.peersRelayStopped, Tone.neutral),
    };
    return ContraCard(
      tone: Tone.highlight,
      child: Row(
        children: [
          ContraAvatar(
            label: identity?.shortId ?? '',
            dimension: Spacing.xxLarge + Spacing.mediumLarge,
          ),
          const SizedBox(width: Spacing.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  identity == null
                      ? l10n.peersMeLoading
                      : l10n.peersMeTitle(identity.shortId),
                  style: theme.bodyStrongTextStyle,
                ),
                const SizedBox(height: Spacing.small),
                Wrap(
                  spacing: Spacing.small,
                  runSpacing: Spacing.xSmall,
                  children: [
                    ContraBadge(label: meshLabel, tone: meshTone, filled: true),
                    ContraBadge(label: relayLabel, tone: relayTone),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeerTile extends StatelessWidget {
  const _PeerTile({required this.peer});

  final Peer peer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ContraListTile(
      leading: ContraAvatar(label: peer.label),
      title: peer.label,
      subtitle: peer.reachableOnMesh
          ? l10n.peersPeerInRange
          : l10n.peersPeerOutOfRange,
      trailing: Wrap(
        spacing: Spacing.xSmall,
        children: [
          if (peer.hasSecureSession)
            ContraBadge(label: l10n.peersPeerSecure, tone: Tone.success),
          if (peer.reachableViaInternet)
            ContraBadge(label: l10n.peersPeerOnline, tone: Tone.accent),
        ],
      ),
    );
  }
}
