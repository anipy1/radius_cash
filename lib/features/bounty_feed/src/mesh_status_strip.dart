import 'package:flutter/material.dart';
import 'package:radius/component_library/component_library.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/l10n/l10n.dart';

/// One line under the app bar: is the radio up, who is in range, is the
/// internet path there.
class MeshStatusStrip extends StatelessWidget {
  const MeshStatusStrip({
    required this.meshStatus,
    required this.relayStatus,
    super.key,
  });

  final MeshStatus meshStatus;
  final RelayStatus relayStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, tone) = switch (meshStatus.phase) {
      MeshPhase.stopped => (l10n.bountyFeedMeshStopped, Tone.neutral),
      MeshPhase.waitingForBluetooth => (
        l10n.bountyFeedMeshWaiting,
        Tone.warning,
      ),
      MeshPhase.unauthorized => (l10n.bountyFeedMeshUnauthorized, Tone.danger),
      MeshPhase.unsupported => (l10n.bountyFeedMeshUnsupported, Tone.danger),
      MeshPhase.running => (
        l10n.bountyFeedMeshRunning(meshStatus.peerCount),
        meshStatus.peerCount > 0 ? Tone.success : Tone.highlight,
      ),
    };
    return Row(
      children: [
        ContraBadge(label: label, tone: tone, filled: tone != Tone.neutral),
        if (relayStatus == RelayStatus.connected) ...[
          const SizedBox(width: Spacing.small),
          ContraBadge(label: l10n.bountyFeedRelayConnected, tone: Tone.accent),
        ],
      ],
    );
  }
}
