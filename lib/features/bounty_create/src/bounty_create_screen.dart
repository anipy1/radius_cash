import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:radius/component_library/component_library.dart';
import 'package:radius/form_fields/form_fields.dart';
import 'package:radius/l10n/l10n.dart';
import 'package:radius/repositories/bounty_repository/bounty_repository.dart';
import 'package:radius/repositories/location_repository/location_repository.dart';

import 'bounty_create_cubit.dart';

class BountyCreateScreen extends StatelessWidget {
  const BountyCreateScreen({
    required this.bountyRepository,
    required this.locationRepository,
    required this.onBountyPosted,
    required this.onCancelled,
    super.key,
  });

  final BountyRepository bountyRepository;
  final LocationRepository locationRepository;
  final ValueChanged<String> onBountyPosted;
  final VoidCallback onCancelled;

  @override
  Widget build(BuildContext context) => BlocProvider<BountyCreateCubit>(
    create: (_) => BountyCreateCubit(
      bountyRepository: bountyRepository,
      locationRepository: locationRepository,
    ),
    child: BountyCreateView(
      onBountyPosted: onBountyPosted,
      onCancelled: onCancelled,
    ),
  );
}

@visibleForTesting
class BountyCreateView extends StatefulWidget {
  const BountyCreateView({
    required this.onBountyPosted,
    required this.onCancelled,
    super.key,
  });

  final ValueChanged<String> onBountyPosted;
  final VoidCallback onCancelled;

  @override
  State<BountyCreateView> createState() => _BountyCreateViewState();
}

class _BountyCreateViewState extends State<BountyCreateView> {
  final _titleFocus = FocusNode();
  final _detailsFocus = FocusNode();
  final _amountFocus = FocusNode();

  BountyCreateCubit get _cubit => context.read<BountyCreateCubit>();

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus) _cubit.onTitleUnfocused();
    });
    _detailsFocus.addListener(() {
      if (!_detailsFocus.hasFocus) _cubit.onDetailsUnfocused();
    });
    _amountFocus.addListener(() {
      if (!_amountFocus.hasFocus) _cubit.onAmountUnfocused();
    });
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _detailsFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _pickCustomExpiry(DateTime current) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current.isAfter(now) ? current : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    _cubit.onExpiryPicked(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.of(context);
    return BlocConsumer<BountyCreateCubit, BountyCreateState>(
      listenWhen: (old, current) =>
          old.submissionStatus != current.submissionStatus,
      listener: (context, state) {
        final message = switch (state.submissionStatus) {
          SubmissionStatus.success => null,
          SubmissionStatus.idle || SubmissionStatus.inProgress => null,
          SubmissionStatus.validationError =>
            l10n.bountyCreateValidationErrorMessage,
          SubmissionStatus.meshNotRunningError =>
            l10n.bountyCreateMeshNotRunningErrorMessage,
          SubmissionStatus.sendError => l10n.bountyCreateSendErrorMessage,
          SubmissionStatus.cacheError => l10n.bountyCreateCacheErrorMessage,
          SubmissionStatus.genericError => l10n.bountyCreateGenericErrorMessage,
        };
        if (state.submissionStatus == SubmissionStatus.success) {
          widget.onBountyPosted(state.postedBountyId!);
        } else if (message != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
          _cubit.onErrorShown();
        }
      },
      builder: (context, state) {
        final busy = state.submissionStatus == SubmissionStatus.inProgress;
        final expiryText = DateFormat.MMMEd(
          Localizations.localeOf(context).toString(),
        ).add_Hm().format(state.expiry.value);

        return Scaffold(
          appBar: ContraAppBar(
            title: l10n.bountyCreateAppBarTitle,
            leading: Center(
              child: ContraIconButton(
                icon: Icons.close,
                semanticLabel: l10n.bountyCreateCancelButtonLabel,
                onPressed: busy ? null : widget.onCancelled,
              ),
            ),
          ),
          body: ListView(
            padding: EdgeInsets.all(theme.screenMargin),
            children: [
              ContraTextField(
                label: l10n.bountyCreateTitleLabel,
                hint: l10n.bountyCreateTitleHint,
                focusNode: _titleFocus,
                enabled: !busy,
                autofocus: true,
                textInputAction: TextInputAction.next,
                onChanged: _cubit.onTitleChanged,
                errorText: switch (state.title.displayError) {
                  null => null,
                  BountyTitleValidationError.empty =>
                    l10n.bountyCreateTitleEmptyError,
                  BountyTitleValidationError.tooLong =>
                    l10n.bountyCreateTitleTooLongError,
                },
              ),
              const SizedBox(height: Spacing.mediumLarge),
              ContraTextField(
                label: l10n.bountyCreateAmountLabel,
                hint: l10n.bountyCreateAmountHint,
                suffixText: l10n.bountyCreateAmountSuffix,
                focusNode: _amountFocus,
                enabled: !busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                onChanged: _cubit.onAmountChanged,
                errorText: switch (state.amount.displayError) {
                  null => null,
                  EuroAmountValidationError.empty =>
                    l10n.bountyCreateAmountEmptyError,
                  EuroAmountValidationError.invalid =>
                    l10n.bountyCreateAmountInvalidError,
                  EuroAmountValidationError.notPositive =>
                    l10n.bountyCreateAmountNotPositiveError,
                  EuroAmountValidationError.tooLarge =>
                    l10n.bountyCreateAmountTooLargeError,
                },
              ),
              const SizedBox(height: Spacing.mediumLarge),
              ContraTextField(
                label: l10n.bountyCreateDetailsLabel,
                hint: l10n.bountyCreateDetailsHint,
                focusNode: _detailsFocus,
                enabled: !busy,
                maxLines: 4,
                onChanged: _cubit.onDetailsChanged,
                errorText: switch (state.details.displayError) {
                  null => null,
                  BountyDetailsValidationError.tooLong =>
                    l10n.bountyCreateDetailsTooLongError,
                },
              ),
              const SizedBox(height: Spacing.mediumLarge),
              Text(l10n.bountyCreateExpiryLabel, style: theme.labelTextStyle),
              const SizedBox(height: Spacing.small),
              Wrap(
                spacing: Spacing.small,
                runSpacing: Spacing.small,
                children: [
                  for (final preset in BountyExpiry.presets)
                    ContraChip(
                      label: _presetLabel(l10n, preset),
                      selected: state.expiryPreset == preset,
                      onSelected: busy
                          ? () {}
                          : () => _cubit.onExpiryPresetSelected(preset),
                    ),
                  ContraChip(
                    label: l10n.bountyCreateExpiryCustomLabel,
                    icon: Icons.event,
                    selected: state.expiryPreset == null,
                    onSelected: busy
                        ? () {}
                        : () => _pickCustomExpiry(state.expiry.value),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.small),
              Text(
                l10n.bountyCreateExpiresAt(expiryText),
                style: theme.captionTextStyle.copyWith(
                  color: state.expiry.displayError == null
                      ? theme.mutedColor
                      : theme.dangerColor,
                ),
              ),
              const SizedBox(height: Spacing.xLarge),
              busy
                  ? ContraButton.inProgress(
                      label: l10n.bountyCreateSubmitButtonLabel,
                    )
                  : ContraButton.primary(
                      label: l10n.bountyCreateSubmitButtonLabel,
                      icon: Icons.campaign_outlined,
                      onPressed: _cubit.onSubmit,
                    ),
            ],
          ),
        );
      },
    );
  }

  static String _presetLabel(AppLocalizations l10n, Duration preset) =>
      preset.inDays >= 1
      ? l10n.bountyCreateExpiryPresetDays(preset.inDays)
      : l10n.bountyCreateExpiryPresetHours(preset.inHours);
}
