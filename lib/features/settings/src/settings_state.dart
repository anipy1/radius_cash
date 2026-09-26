part of 'settings_cubit.dart';

enum ForgetStatus {
  idle,
  inProgress,

  /// Nothing can hear a cancellation right now and there is something
  /// open. Waiting for the person to say forget anyway, or keep it.
  unreachable,
  done,
  failed,
}

class SettingsState extends Equatable {
  const SettingsState({
    this.darkMode = DarkModePreference.alwaysLight,
    this.identity,
    this.forgetStatus = ForgetStatus.idle,
    this.preferenceFailed = false,
    this.outlook,
  });

  final DarkModePreference darkMode;

  /// Null until loaded, or when the load failed; the screen shows a
  /// placeholder either way.
  final Identity? identity;
  final ForgetStatus forgetStatus;

  /// The last write to disk did not take. The choice is still shown, since
  /// it applies for this run; it just will not survive a restart.
  final bool preferenceFailed;

  /// What forgetting would leave behind, once looked up.
  final RetirementOutlook? outlook;

  SettingsState copyWith({
    DarkModePreference? darkMode,
    Identity? identity,
    ForgetStatus? forgetStatus,
    bool? preferenceFailed,
    RetirementOutlook? outlook,
  }) => SettingsState(
    darkMode: darkMode ?? this.darkMode,
    identity: identity ?? this.identity,
    forgetStatus: forgetStatus ?? this.forgetStatus,
    preferenceFailed: preferenceFailed ?? this.preferenceFailed,
    outlook: outlook ?? this.outlook,
  );

  @override
  List<Object?> get props => [
    darkMode,
    identity,
    forgetStatus,
    preferenceFailed,
    outlook,
  ];
}
