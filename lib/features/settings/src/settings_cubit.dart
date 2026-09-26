import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/repositories/bounty_repository/bounty_repository.dart';
import 'package:radius/repositories/identity_repository/identity_repository.dart';
import 'package:radius/repositories/mesh_repository/mesh_repository.dart';
import 'package:radius/repositories/settings_repository/settings_repository.dart';

part 'settings_state.dart';

/// A Cubit: one preference read once and written on tap, one identity read
/// once, one destructive action. Nothing here needs event traffic control.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required SettingsRepository settingsRepository,
    required IdentityRepository identityRepository,
    required MeshRepository meshRepository,
    required BountyRepository bountyRepository,
  }) : _settings = settingsRepository,
       _identity = identityRepository,
       _mesh = meshRepository,
       _bounties = bountyRepository,
       super(const SettingsState()) {
    _load();
  }

  final SettingsRepository _settings;
  final IdentityRepository _identity;
  final MeshRepository _mesh;
  final BountyRepository _bounties;

  /// Set once the user picks, so a slow read from disk cannot undo a
  /// choice made while it was still on its way.
  bool _chosen = false;

  Future<void> _load() async {
    try {
      final preference = await _settings.getDarkModePreference().first;
      if (!isClosed && !_chosen) emit(state.copyWith(darkMode: preference));
    } catch (_) {
      // The default is already in the state.
    }
    try {
      final identity = await _identity.getIdentity();
      if (!isClosed) emit(state.copyWith(identity: identity));
    } on IdentityLoadException {
      // Shown as a placeholder.
    }
  }

  Future<void> onDarkModeSelected(DarkModePreference preference) async {
    _chosen = true;
    if (preference == state.darkMode) return;
    emit(state.copyWith(darkMode: preference, preferenceFailed: false));
    try {
      await _settings.setDarkModePreference(preference);
    } on PreferencesException {
      if (!isClosed) emit(state.copyWith(preferenceFailed: true));
    }
  }

  /// First looks at what would be left behind. If there is something open
  /// and no way to tell anyone, stops and asks; the person may prefer to
  /// come back into range first. Otherwise closes everything under the old
  /// key, stops the radio and relays, and erases the seed.
  Future<void> onForgetConfirmed() async {
    if (state.forgetStatus == ForgetStatus.inProgress) return;
    emit(state.copyWith(forgetStatus: ForgetStatus.inProgress));
    RetirementOutlook? outlook;
    try {
      outlook = await _bounties.retirementOutlook();
    } catch (_) {
      // Cannot even read the cache. Nothing to warn about that we know of.
    }
    if (outlook != null &&
        !outlook.canAnnounce &&
        outlook.leavesSomethingBehind) {
      if (!isClosed) {
        emit(
          state.copyWith(
            forgetStatus: ForgetStatus.unreachable,
            outlook: outlook,
          ),
        );
      }
      return;
    }
    await _retireAndErase();
  }

  /// The person saw what stays behind and wants to go ahead anyway.
  Future<void> onForgetAnyway() async {
    if (state.forgetStatus != ForgetStatus.unreachable) return;
    emit(state.copyWith(forgetStatus: ForgetStatus.inProgress));
    await _retireAndErase();
  }

  void onForgetAbandoned() {
    if (state.forgetStatus != ForgetStatus.unreachable) return;
    emit(state.copyWith(forgetStatus: ForgetStatus.idle));
  }

  Future<void> _retireAndErase() async {
    try {
      await _bounties.retireIdentity();
    } catch (_) {
      // Best effort by design; the outlook already said what could reach.
    }
    try {
      await _mesh.stopRelays();
    } catch (_) {
      // Already down, or never up. Either way not a reason to keep the seed.
    }
    try {
      await _mesh.stop();
    } catch (_) {
      // Same.
    }
    try {
      await _identity.forgetIdentity();
      if (!isClosed) emit(state.copyWith(forgetStatus: ForgetStatus.done));
    } on IdentityForgetException {
      if (!isClosed) emit(state.copyWith(forgetStatus: ForgetStatus.failed));
    } on PreferencesException {
      // The seed is gone, which is what was asked; a cache that did not
      // clear is wiped on the next launch's onboarding anyway.
      if (!isClosed) emit(state.copyWith(forgetStatus: ForgetStatus.done));
    }
  }
}
