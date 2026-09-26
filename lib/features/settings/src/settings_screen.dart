import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:radius/component_library/component_library.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/l10n/l10n.dart';
import 'package:radius/repositories/bounty_repository/bounty_repository.dart';
import 'package:radius/repositories/identity_repository/identity_repository.dart';
import 'package:radius/repositories/mesh_repository/mesh_repository.dart';
import 'package:radius/repositories/settings_repository/settings_repository.dart';

import 'settings_cubit.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.settingsRepository,
    required this.identityRepository,
    required this.meshRepository,
    required this.bountyRepository,
    required this.onBackPressed,
    required this.onIdentityForgotten,
    super.key,
  });

  final SettingsRepository settingsRepository;
  final IdentityRepository identityRepository;
  final MeshRepository meshRepository;
  final BountyRepository bountyRepository;
  final VoidCallback onBackPressed;

  /// The seed is gone. Whoever composed the app decides what that means;
  /// this screen only reports it.
  final VoidCallback onIdentityForgotten;

  @override
  Widget build(BuildContext context) => BlocProvider<SettingsCubit>(
    create: (_) => SettingsCubit(
      settingsRepository: settingsRepository,
      identityRepository: identityRepository,
      meshRepository: meshRepository,
      bountyRepository: bountyRepository,
    ),
    child: SettingsView(
      onBackPressed: onBackPressed,
      onIdentityForgotten: onIdentityForgotten,
    ),
  );
}

@visibleForTesting
class SettingsView extends StatelessWidget {
  const SettingsView({
    required this.onBackPressed,
    required this.onIdentityForgotten,
    super.key,
  });

  final VoidCallback onBackPressed;
  final VoidCallback onIdentityForgotten;

  static const _darkModeOrder = [
    DarkModePreference.alwaysLight,
    DarkModePreference.alwaysDark,
    DarkModePreference.useSystemSettings,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.of(context);
    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: (before, after) => before.forgetStatus != after.forgetStatus,
      listener: (context, state) {
        switch (state.forgetStatus) {
          case ForgetStatus.done:
            onIdentityForgotten();
          case ForgetStatus.unreachable:
            _askToForgetAnyway(context, context.read<SettingsCubit>());
          case ForgetStatus.idle:
          case ForgetStatus.inProgress:
          case ForgetStatus.failed:
            break;
        }
      },
      builder: (context, state) {
        final cubit = context.read<SettingsCubit>();
        return Scaffold(
          appBar: ContraAppBar(
            title: l10n.settingsAppBarTitle,
            leading: Center(
              child: ContraIconButton(
                icon: Icons.arrow_back,
                semanticLabel: l10n.settingsBackButtonLabel,
                onPressed: onBackPressed,
              ),
            ),
          ),
          body: state.forgetStatus == ForgetStatus.done
              ? _Forgotten()
              : ListView(
                  padding: EdgeInsets.all(theme.screenMargin),
                  children: [
                    Text(
                      l10n.settingsAppearanceTitle,
                      style: theme.subtitleTextStyle,
                    ),
                    const SizedBox(height: Spacing.medium),
                    ContraSegmentedControl(
                      labels: [
                        l10n.settingsDarkModeLight,
                        l10n.settingsDarkModeDark,
                        l10n.settingsDarkModeSystem,
                      ],
                      selectedIndex: _darkModeOrder.indexOf(state.darkMode),
                      onSelected: (i) =>
                          cubit.onDarkModeSelected(_darkModeOrder[i]),
                    ),
                    if (state.preferenceFailed) ...[
                      const SizedBox(height: Spacing.small),
                      Text(
                        l10n.settingsPreferenceFailed,
                        style: theme.captionTextStyle,
                      ),
                    ],
                    const SizedBox(height: Spacing.large),
                    Text(
                      l10n.settingsIdentityTitle,
                      style: theme.subtitleTextStyle,
                    ),
                    const SizedBox(height: Spacing.medium),
                    _IdentitySection(identity: state.identity),
                    const SizedBox(height: Spacing.large),
                    Text(
                      l10n.settingsDangerTitle,
                      style: theme.subtitleTextStyle,
                    ),
                    const SizedBox(height: Spacing.medium),
                    Text(
                      l10n.settingsForgetExplanation,
                      style: theme.bodyTextStyle,
                    ),
                    const SizedBox(height: Spacing.medium),
                    if (state.forgetStatus == ForgetStatus.inProgress)
                      ContraButton.inProgress(
                        label: l10n.settingsForgetInProgress,
                      )
                    else
                      ContraButton.tonal(
                        label: l10n.settingsForgetButtonLabel,
                        tone: Tone.danger,
                        icon: Icons.delete_outline,
                        onPressed: () => _confirmForget(context, cubit),
                      ),
                    if (state.forgetStatus == ForgetStatus.failed) ...[
                      const SizedBox(height: Spacing.small),
                      Text(
                        l10n.settingsForgetFailed,
                        style: theme.captionTextStyle,
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Future<void> _confirmForget(BuildContext context, SettingsCubit cubit) async {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.of(context);
    final confirmed = await showContraBottomSheet<bool>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.settingsForgetConfirmTitle, style: theme.titleTextStyle),
          const SizedBox(height: Spacing.medium),
          Text(l10n.settingsForgetConfirmBody, style: theme.bodyTextStyle),
          const SizedBox(height: Spacing.large),
          ContraButton.tonal(
            label: l10n.settingsForgetConfirmButtonLabel,
            tone: Tone.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: Spacing.medium),
          ContraButton.secondary(
            label: l10n.settingsForgetKeepButtonLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.onForgetConfirmed();
  }

  /// Nothing can hear a cancellation. Says exactly what stays behind and
  /// lets the person choose, since coming back into range first is a real
  /// option and the sheet is the only place they learn that.
  Future<void> _askToForgetAnyway(
    BuildContext context,
    SettingsCubit cubit,
  ) async {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.of(context);
    final outlook = cubit.state.outlook;
    final anyway = await showContraBottomSheet<bool>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.settingsForgetUnreachableTitle,
            style: theme.titleTextStyle,
          ),
          const SizedBox(height: Spacing.medium),
          Text(
            l10n.settingsForgetUnreachableBody(
              outlook?.openBountyTitles.length ?? 0,
              outlook?.pendingClaimCount ?? 0,
            ),
            style: theme.bodyTextStyle,
          ),
          if (outlook != null && outlook.openBountyTitles.isNotEmpty) ...[
            const SizedBox(height: Spacing.medium),
            for (final title in outlook.openBountyTitles)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.xSmall),
                child: Text(
                  l10n.settingsForgetUnreachableItem(title),
                  style: theme.captionTextStyle,
                ),
              ),
          ],
          const SizedBox(height: Spacing.large),
          ContraButton.tonal(
            label: l10n.settingsForgetAnywayButtonLabel,
            tone: Tone.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: Spacing.medium),
          ContraButton.secondary(
            label: l10n.settingsForgetKeepButtonLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
    if (anyway ?? false) {
      await cubit.onForgetAnyway();
    } else {
      cubit.onForgetAbandoned();
    }
  }
}

class _IdentitySection extends StatelessWidget {
  const _IdentitySection({required this.identity});

  final Identity? identity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final identity = this.identity;
    if (identity == null) {
      return ContraListTile(title: l10n.settingsIdentityLoading);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContraListTile(
          leading: ContraAvatar(label: identity.shortId),
          title: l10n.settingsIdentityLabel(identity.shortId),
          subtitle: l10n.settingsIdentityPeerId(identity.peerId),
        ),
        const SizedBox(height: Spacing.medium),
        ContraListTile(
          title: l10n.settingsNpubTitle,
          subtitle: identity.npub,
          trailing: ContraIconButton(
            icon: Icons.copy_outlined,
            semanticLabel: l10n.settingsCopyNpubButtonLabel,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: identity.npub));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.settingsNpubCopied)));
            },
          ),
        ),
      ],
    );
  }
}

class _Forgotten extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(theme.screenMargin),
      child: ContraEmptyState(
        icon: Icons.restart_alt,
        illustration: const ContraPeep(
          asset: PeepAssets.standingSmiling,
          height: Spacing.xxxLarge * 2,
        ),
        title: l10n.settingsForgottenTitle,
        body: l10n.settingsForgottenBody,
      ),
    );
  }
}
