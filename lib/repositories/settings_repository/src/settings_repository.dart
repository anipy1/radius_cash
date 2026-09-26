import 'package:meta/meta.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/local_storage/local_storage.dart';
import 'package:rxdart/rxdart.dart';

import 'mappers/mappers.dart';
import 'settings_local_storage.dart';

/// Preferences the whole app reads and one screen writes.
class SettingsRepository {
  SettingsRepository({
    required KeyValueStorage keyValueStorage,
    @visibleForTesting SettingsLocalStorage? localStorage,
  }) : _storage =
           localStorage ??
           SettingsLocalStorage(keyValueStorage: keyValueStorage);

  final SettingsLocalStorage _storage;

  BehaviorSubject<DarkModePreference>? _darkMode;

  /// Replays the current value to every listener, so main.dart and the
  /// settings screen agree without either reading disk twice.
  Stream<DarkModePreference> getDarkModePreference() {
    final existing = _darkMode;
    if (existing != null) return existing.stream;
    final subject = BehaviorSubject<DarkModePreference>();
    _darkMode = subject;
    _storage
        .getDarkMode()
        .then((v) => v.toDarkModePreference())
        .catchError((Object _) => DarkModePreference.alwaysLight)
        .then((p) {
          if (!subject.isClosed && !subject.hasValue) subject.add(p);
        });
    return subject.stream;
  }

  Future<void> setDarkModePreference(DarkModePreference preference) async {
    // Shown at once; the disk is the slow part and a failure there is
    // reported, not silently undone on screen.
    final subject = _darkMode;
    if (subject != null && !subject.isClosed) subject.add(preference);
    await _storage.setDarkMode(preference.toCacheValue());
  }

  Future<void> dispose() async => _darkMode?.close();
}
