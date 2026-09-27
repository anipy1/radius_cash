import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:radius/component_library/component_library.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/l10n/l10n.dart';
import 'package:radius/repositories/bounty_repository/bounty_repository.dart';

import 'bounty_detail_bloc.dart';

class BountyDetailScreen extends StatelessWidget {
  const BountyDetailScreen({
    required this.bountyId,
    required this.bountyRepository,
    required this.onBackPressed,
    super.key,
  });

  final String bountyId;
  final BountyRepository bountyRepository;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) => BlocProvider<BountyDetailBloc>(
    create: (_) => BountyDetailBloc(
      bountyId: bountyId,
      bountyRepository: bountyRepository,
    ),
    child: BountyDetailView(onBackPressed: onBackPressed),
  );
}

@visibleForTesting
class BountyDetailView extends StatefulWidget {
  const BountyDetailView({required this.onBackPressed, super.key});

  final VoidCallback onBackPressed;

  @override
  State<BountyDetailView> createState() => _BountyDetailViewState();
}

class _BountyDetailViewState extends State<BountyDetailView> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.of(context);
    return BlocConsumer<BountyDetailBloc, BountyDetailState>(
      listenWhen: (old, current) =>
          current is BountyDetailSuccess &&
          (old is! BountyDetailSuccess ||
              old.actionStatus != current.actionStatus),
      listener: (context, state) {
        if (state is! BountyDetailSuccess) return;
        final message = switch (state.actionStatus) {
          ActionStatus.idle || ActionStatus.inProgress => null,
          ActionStatus.closedError => l10n.bountyDetailClosedErrorMessage,
          ActionStatus.meshNotRunningError =>
            l10n.bountyDetailMeshNotRunningErrorMessage,
          ActionStatus.sendError => l10n.bountyDetailSendErrorMessage,
          ActionStatus.cacheError => l10n.bountyDetailCacheErrorMessage,
          ActionStatus.validationError =>
            l10n.bountyDetailValidationErrorMessage,
          ActionStatus.genericError => l10n.bountyDetailGenericErrorMessage,
        };
        if (message != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
          context.read<BountyDetailBloc>().add(const BountyDetailErrorShown());
        }
      },
      builder: (context, state) => Scaffold(
        appBar: ContraAppBar(
          title: l10n.bountyDetailAppBarTitle,
          leading: Center(
            child: ContraIconButton(
              icon: Icons.arrow_back,
              semanticLabel: l10n.bountyDetailBackButtonLabel,
              onPressed: widget.onBackPressed,
            ),
          ),
        ),
        body: switch (state) {
          BountyDetailInProgress() => const ContraProgress(),
          BountyDetailFailure() => ContraEmptyState(
            icon: Icons.search_off,
            title: l10n.bountyDetailNotFoundTitle,
            body: l10n.bountyDetailNotFoundBody,
          ),
          BountyDetailSuccess() => ListView(
            padding: EdgeInsets.all(theme.screenMargin),
            children: [
              _Header(bounty: state.bounty),
              const SizedBox(height: Spacing.large),
              if (state.bounty.isMine)
                _AuthorSection(state: state)
              else
                _ClaimantSection(state: state, note: _note),
              if (state.bounty.status == BountyStatus.done ||
                  state.bounty.status == BountyStatus.paid) ...[
                const SizedBox(height: Spacing.large),
                _WitnessSection(bounty: state.bounty),
              ],
            ],
          ),
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.bounty});

  final Bounty bounty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.of(context);
    final now = DateTime.now();
    final expires = DateFormat.MMMEd(
      Localizations.localeOf(context).toString(),
    ).add_Hm().format(bounty.expiresAt.toLocal());
    return ContraCard(
      tone: toneFor(bounty.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(bounty.title, style: theme.titleTextStyle)),
              const SizedBox(width: Spacing.small),
              ContraAmountBadge(cents: bounty.amountCents, symbol: '€'),
            ],
          ),
          const SizedBox(height: Spacing.medium),
          Row(
            children: [
              ContraAvatar(
                label: bounty.authorLabel,
                dimension: Spacing.xLarge,
              ),
              const SizedBox(width: Spacing.small),
              Text(
                bounty.isMine
                    ? l10n.bountyDetailAuthorYou
                    : l10n.bountyDetailAuthorLabel(bounty.authorLabel),
                style: theme.smallTextStyle,
              ),
            ],
          ),
          if (bounty.details.isNotEmpty) ...[
            const SizedBox(height: Spacing.medium),
            Text(bounty.details, style: theme.bodyTextStyle),
          ],
          const SizedBox(height: Spacing.medium),
          Wrap(
            spacing: Spacing.small,
            runSpacing: Spacing.small,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ContraBadge(
                label: statusLabel(l10n, bounty.status),
                tone: toneFor(bounty.status),
              ),
              Text(
                bounty.isExpiredAt(DateTime.now())
                    ? l10n.bountyDetailExpired
                    : l10n.bountyDetailExpiresAt(expires),
                style: theme.captionTextStyle.copyWith(color: theme.mutedColor),
              ),
              if (bounty.claimantLabel != null)
                Text(
                  l10n.bountyDetailClaimedBy(bounty.claimantLabel!),
                  style: theme.captionTextStyle.copyWith(
                    color: theme.mutedColor,
                  ),
                ),
            ],
          ),
          if (bounty.isPosterAwayAt(now)) ...[
            const SizedBox(height: Spacing.medium),
            Text(
              l10n.bountyDetailPosterAway(
                bounty.sinceHeardFromPosterAt(now).inMinutes,
              ),
              style: theme.captionTextStyle.copyWith(color: theme.mutedColor),
            ),
          ] else if (bounty.viaInternet) ...[
            const SizedBox(height: Spacing.medium),
            Text(
              l10n.bountyDetailViaInternet,
              style: theme.captionTextStyle.copyWith(color: theme.mutedColor),
            ),
          ],
        ],
      ),
    );
  }
}

/// What somebody who did not post it can do: offer, or see how the offer
/// went.
class _ClaimantSection extends StatelessWidget {
  const _ClaimantSection({required this.state, required this.note});

  final BountyDetailSuccess state;
  final TextEditingController note;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.of(context);
    final bloc = context.read<BountyDetailBloc>();
    final mine = state.myClaim;

    if (mine == null) {
      if (!state.bounty.isClaimableAt(DateTime.now())) {
        return Text(
          l10n.bountyDetailNotClaimable,
          style: theme.bodyTextStyle.copyWith(color: theme.mutedColor),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContraTextField(
            label: l10n.bountyDetailNoteLabel,
            hint: l10n.bountyDetailNoteHint,
            controller: note,
            maxLines: 2,
            maxLength: BountyRepository.maxNoteBytes,
            enabled: !state.isBusy,
          ),
          const SizedBox(height: Spacing.mediumLarge),
          state.isBusy
              ? ContraButton.inProgress(
                  label: l10n.bountyDetailClaimButtonLabel,
                )
              : ContraButton.primary(
                  label: l10n.bountyDetailClaimButtonLabel,
                  icon: Icons.front_hand_outlined,
                  onPressed: () =>
                      bloc.add(BountyDetailClaimRequested(note: note.text)),
                ),
        ],
      );
    }

    final (label, tone) = switch (mine.status) {
      ClaimStatus.pending => (
        mine.delivered
            ? l10n.bountyDetailMyClaimDelivered
            : l10n.bountyDetailMyClaimPending,
        Tone.warning,
      ),
      ClaimStatus.accepted => (l10n.bountyDetailMyClaimAccepted, Tone.success),
      ClaimStatus.declined => (l10n.bountyDetailMyClaimDeclined, Tone.danger),
      ClaimStatus.done => (l10n.bountyDetailMyClaimDone, Tone.success),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContraCard(
          tone: tone,
          raised: false,
          child: Text(label, style: theme.bodyStrongTextStyle),
        ),
        if (mine.status == ClaimStatus.accepted &&
            state.bounty.status == BountyStatus.claimed) ...[
          const SizedBox(height: Spacing.mediumLarge),
          state.isBusy
              ? ContraButton.inProgress(label: l10n.bountyDetailDoneButtonLabel)
              : ContraButton.tonal(
                  label: l10n.bountyDetailDoneButtonLabel,
                  tone: Tone.success,
                  icon: Icons.check,
                  onPressed: () => bloc.add(const BountyDetailDoneRequested()),
                ),
        ],
      ],
    );
  }
}

/// What the author can do: pick somebody, then see it through.
class _AuthorSection extends StatelessWidget {
  const _AuthorSection({required this.state});

  final BountyDetailSuccess state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.of(context);
    final bloc = context.read<BountyDetailBloc>();
    final bounty = state.bounty;
    final busy = state.isBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.bountyDetailClaimsTitle(state.claims.length),
          style: theme.subtitleTextStyle,
        ),
        const SizedBox(height: Spacing.medium),
        if (state.claims.isEmpty)
          Text(
            l10n.bountyDetailNoClaimsYet,
            style: theme.bodyTextStyle.copyWith(color: theme.mutedColor),
          ),
        for (final claim in state.claims) ...[
          ContraListTile(
            leading: ContraAvatar(label: claim.claimantLabel),
            title: claim.claimantLabel,
            subtitle: claim.note.isEmpty ? null : claim.note,
            trailing:
                claim.status == ClaimStatus.pending &&
                    bounty.status == BountyStatus.open
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ContraIconButton(
                        icon: Icons.check,
                        tone: Tone.success,
                        semanticLabel: l10n.bountyDetailAcceptButtonLabel,
                        onPressed: busy
                            ? null
                            : () => bloc.add(
                                BountyDetailAcceptRequested(claim.claimantId),
                              ),
                      ),
                      const SizedBox(width: Spacing.small),
                      ContraIconButton(
                        icon: Icons.close,
                        tone: Tone.danger,
                        semanticLabel: l10n.bountyDetailDeclineButtonLabel,
                        onPressed: busy
                            ? null
                            : () => bloc.add(
                                BountyDetailDeclineRequested(claim.claimantId),
                              ),
                      ),
                    ],
                  )
                : ContraBadge(
                    label: switch (claim.status) {
                      ClaimStatus.pending => l10n.bountyDetailClaimPending,
                      ClaimStatus.accepted => l10n.bountyDetailClaimAccepted,
                      ClaimStatus.declined => l10n.bountyDetailClaimDeclined,
                      ClaimStatus.done => l10n.bountyDetailClaimDone,
                    },
                    tone: switch (claim.status) {
                      ClaimStatus.pending => Tone.warning,
                      ClaimStatus.accepted || ClaimStatus.done => Tone.success,
                      ClaimStatus.declined => Tone.danger,
                    },
                  ),
          ),
          const SizedBox(height: Spacing.small),
        ],
        const SizedBox(height: Spacing.mediumLarge),
        if (bounty.status == BountyStatus.claimed)
          _action(
            busy,
            l10n.bountyDetailMarkDoneButtonLabel,
            Tone.success,
            Icons.check,
            () => bloc.add(const BountyDetailDoneRequested()),
          ),
        if (bounty.status == BountyStatus.done)
          _action(
            busy,
            l10n.bountyDetailMarkPaidButtonLabel,
            Tone.accent,
            Icons.euro,
            () => bloc.add(const BountyDetailPaidRequested()),
          ),
        if (bounty.status == BountyStatus.open ||
            bounty.status == BountyStatus.claimed) ...[
          const SizedBox(height: Spacing.small),
          _action(
            busy,
            l10n.bountyDetailCancelButtonLabel,
            Tone.danger,
            Icons.delete_outline,
            () => bloc.add(const BountyDetailCancelRequested()),
          ),
        ],
      ],
    );
  }

  Widget _action(
    bool busy,
    String label,
    Tone tone,
    IconData icon,
    VoidCallback onPressed,
  ) => busy
      ? ContraButton.inProgress(label: label)
      : ContraButton.tonal(
          label: label,
          tone: tone,
          icon: icon,
          onPressed: onPressed,
        );
}

@visibleForTesting
Tone toneFor(BountyStatus status) => switch (status) {
  BountyStatus.open => Tone.neutral,
  BountyStatus.claimed => Tone.accent,
  BountyStatus.done || BountyStatus.paid => Tone.success,
  BountyStatus.cancelled => Tone.danger,
};

@visibleForTesting
String statusLabel(AppLocalizations l10n, BountyStatus status) =>
    switch (status) {
      BountyStatus.open => l10n.bountyDetailStatusOpen,
      BountyStatus.claimed => l10n.bountyDetailStatusClaimed,
      BountyStatus.done => l10n.bountyDetailStatusDone,
      BountyStatus.paid => l10n.bountyDetailStatusPaid,
      BountyStatus.cancelled => l10n.bountyDetailStatusCancelled,
    };

/// Who was in the room when this was finished.
///
/// Only shown once a bounty is done, because that is the moment the
/// signatures are about. An empty list is shown rather than hidden: "nobody
/// signed" is a fact about the completion, not a missing section.
class _WitnessSection extends StatelessWidget {
  const _WitnessSection({required this.bounty});

  final Bounty bounty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.bountyDetailWitnessesTitle(bounty.witnessCount),
          style: theme.subtitleTextStyle,
        ),
        const SizedBox(height: Spacing.medium),
        if (bounty.witnessLabels.isEmpty)
          Text(
            l10n.bountyDetailNoWitnesses,
            style: theme.bodyTextStyle.copyWith(color: theme.mutedColor),
          ),
        for (final label in bounty.witnessLabels) ...[
          ContraListTile(
            leading: ContraAvatar(label: label),
            title: label,
          ),
          const SizedBox(height: Spacing.small),
        ],
      ],
    );
  }
}
