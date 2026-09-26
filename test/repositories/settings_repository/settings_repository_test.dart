import 'package:flutter_test/flutter_test.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/local_storage/local_storage.dart';
import 'package:radius/repositories/settings_repository/settings_repository.dart';
import 'package:radius/repositories/settings_repository/src/settings_local_storage.dart';

class _MemoryPrefs extends SettingsLocalStorage {
  _MemoryPrefs()
    : super(keyValueStorage: KeyValueStorage(initialize: (_) async {}));

  String? darkMode;
  bool broken = false;

  @override
  Future<String?> getDarkMode() async {
    if (broken) throw PreferencesException();
    return darkMode;
  }

  @override
  Future<void> setDarkMode(String value) async {
    if (broken) throw PreferencesException();
    darkMode = value;
  }
}

void main() {
  late _MemoryPrefs prefs;

  setUp(() => prefs = _MemoryPrefs());

  SettingsRepository build() => SettingsRepository(
    keyValueStorage: KeyValueStorage(initialize: (_) async {}),
    localStorage: prefs,
  );

  test('nothing stored means light, the kit default', () async {
    final repo = build();
    expect(
      await repo.getDarkModePreference().first,
      DarkModePreference.alwaysLight,
    );
    await repo.dispose();
  });

  test('a stored choice comes back', () async {
    prefs.darkMode = 'alwaysDark';
    final repo = build();
    expect(
      await repo.getDarkModePreference().first,
      DarkModePreference.alwaysDark,
    );
    await repo.dispose();
  });

  test('a value this build does not know is the default', () async {
    prefs.darkMode = 'sepia';
    final repo = build();
    expect(
      await repo.getDarkModePreference().first,
      DarkModePreference.alwaysLight,
    );
    await repo.dispose();
  });

  test('setting is shown at once and written to disk', () async {
    final repo = build();
    final seen = <DarkModePreference>[];
    final sub = repo.getDarkModePreference().listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    await repo.setDarkModePreference(DarkModePreference.useSystemSettings);
    await Future<void>.delayed(Duration.zero);
    expect(seen, [
      DarkModePreference.alwaysLight,
      DarkModePreference.useSystemSettings,
    ]);
    expect(prefs.darkMode, 'useSystemSettings');
    await sub.cancel();
    await repo.dispose();
  });

  test('a disk that will not write still reports the failure', () async {
    final repo = build();
    await repo.getDarkModePreference().first;
    prefs.broken = true;
    expect(
      repo.setDarkModePreference(DarkModePreference.alwaysDark),
      throwsA(isA<PreferencesException>()),
    );
    await repo.dispose();
  });

  test('a disk that will not read falls back to the default', () async {
    prefs.broken = true;
    final repo = build();
    expect(
      await repo.getDarkModePreference().first,
      DarkModePreference.alwaysLight,
    );
    await repo.dispose();
  });
}
