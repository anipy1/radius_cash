import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:radius/component_library/component_library.dart';
import 'package:radius/l10n/l10n.dart';
import 'package:radius/repositories/identity_repository/identity_repository.dart';

import 'identity_onboarding_cubit.dart';

class IdentityOnboardingScreen extends StatelessWidget {
  const IdentityOnboardingScreen({
    required this.identityRepository,
    required this.onFinished,
    super.key,
  });

  final IdentityRepository identityRepository;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) => BlocProvider<IdentityOnboardingCubit>(
    create: (_) =>
        IdentityOnboardingCubit(identityRepository: identityRepository),
    child: IdentityOnboardingView(onFinished: onFinished),
  );
}

@visibleForTesting
class IdentityOnboardingView extends StatefulWidget {
  const IdentityOnboardingView({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<IdentityOnboardingView> createState() => _IdentityOnboardingViewState();
}

class _IdentityOnboardingViewState extends State<IdentityOnboardingView> {
  // Starts on whatever page the cubit says, so a rebuilt view does not snap
  // back to the first one.
  late final _pages = PageController(
    initialPage: context.read<IdentityOnboardingCubit>().state.page,
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.of(context);
    return BlocConsumer<IdentityOnboardingCubit, IdentityOnboardingState>(
      listenWhen: (old, current) =>
          old.status != current.status || old.page != current.page,
      listener: (context, state) {
        if (state.status == OnboardingStatus.finished) {
          widget.onFinished();
          return;
        }
        if (_pages.hasClients && _pages.page?.round() != state.page) {
          _pages.animateToPage(
            state.page,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<IdentityOnboardingCubit>();
        final busy = state.status == OnboardingStatus.finishing;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: cubit.onPageChanged,
                    children: [
                      _Page(
                        peep: PeepAssets.groupChatting,
                        title: l10n.onboardingWelcomeTitle,
                        body: l10n.onboardingWelcomeBody,
                      ),
                      _IdentityPage(state: state),
                      _Page(
                        peep: PeepAssets.standingPointing,
                        title: l10n.onboardingRadioTitle,
                        body: l10n.onboardingRadioBody,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(theme.screenMargin),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Dots(
                        count: IdentityOnboardingCubit.pageCount,
                        current: state.page,
                      ),
                      const SizedBox(height: Spacing.large),
                      if (state.isLastPage)
                        busy
                            ? ContraButton.inProgress(
                                label: l10n.onboardingStartButtonLabel,
                              )
                            : ContraButton.primary(
                                label: l10n.onboardingStartButtonLabel,
                                icon: Icons.bluetooth,
                                onPressed: cubit.onFinish,
                              )
                      else
                        ContraButton.primary(
                          label: l10n.onboardingNextButtonLabel,
                          icon: Icons.arrow_forward,
                          onPressed: cubit.onNext,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.peep, required this.title, required this.body});

  final String peep;
  final String title;
  final String body;

  /// Tall enough to read as a drawing, short enough to leave room for the
  /// text on a small phone.
  static const _peepHeight = Spacing.xxxLarge * 4;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The drawing gives way first on a short screen; the words never do.
        final peepHeight = _peepHeight
            .clamp(0.0, constraints.maxHeight * 0.4)
            .toDouble();
        return SingleChildScrollView(
          padding: EdgeInsets.all(theme.screenMargin),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - theme.screenMargin * 2).clamp(
                0.0,
                double.infinity,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: ContraPeep(asset: peep, height: peepHeight),
                ),
                const SizedBox(height: Spacing.xLarge),
                Text(title, style: theme.headingTextStyle),
                const SizedBox(height: Spacing.medium),
                Text(
                  body,
                  style: theme.bodyTextStyle.copyWith(color: theme.mutedColor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// This is you: the label people will know this phone by, and the Nostr
/// address it can be reached at when the radio cannot.
class _IdentityPage extends StatelessWidget {
  const _IdentityPage({required this.state});

  final IdentityOnboardingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.of(context);
    final identity = state.identity;
    return Padding(
      padding: EdgeInsets.all(theme.screenMargin),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (identity == null)
            SizedBox(
              width: Spacing.xxxLarge * 2,
              height: Spacing.xxxLarge * 2,
              child: state.identityFailed
                  ? Icon(Icons.error_outline, color: theme.dangerColor)
                  : const ContraProgress(),
            )
          else
            ContraAvatar(
              label: identity.shortId,
              dimension: Spacing.xxxLarge * 2,
            ),
          const SizedBox(height: Spacing.xLarge),
          Text(
            identity == null
                ? l10n.onboardingIdentityTitleLoading
                : l10n.onboardingIdentityTitle(identity.shortId),
            style: theme.headingTextStyle,
          ),
          const SizedBox(height: Spacing.medium),
          Text(
            l10n.onboardingIdentityBody,
            style: theme.bodyTextStyle.copyWith(color: theme.mutedColor),
          ),
          if (identity != null) ...[
            const SizedBox(height: Spacing.large),
            ContraCard(
              raised: false,
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.mediumLarge,
                vertical: Spacing.medium,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.onboardingNpubLabel,
                          style: theme.labelTextStyle,
                        ),
                        Text(
                          identity.npub,
                          style: theme.captionTextStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.small),
                  ContraIconButton(
                    icon: Icons.copy,
                    semanticLabel: l10n.onboardingCopyNpubLabel,
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: identity.npub),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(content: Text(l10n.onboardingNpubCopied)),
                        );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: Spacing.xSmall),
            width: i == current ? Spacing.large : Spacing.small,
            height: Spacing.small,
            decoration: BoxDecoration(
              color: i == current ? theme.accentColor : theme.surfaceColor,
              border: theme.border,
              borderRadius: BorderRadius.circular(Spacing.small),
            ),
          ),
      ],
    );
  }
}
