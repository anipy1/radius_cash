import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/local_storage/local_storage.dart';

/// The settings box, as the settings repository sees it.
class SettingsLocalStorage {
  const SettingsLocalStorage({required this.keyValueStorage});

  final KeyValueStorage keyValueStorage;

  static const darkModeKey = 'darkMode';

  Future<String?> getDarkMode() => _guard(() async {
    final box = await keyValueStorage.settingsBox;
    return box.get(darkModeKey) as String?;
  });

  Future<void> setDarkMode(String value) => _guard(() async {
    final box = await keyValueStorage.settingsBox;
    await box.put(darkModeKey, value);
  });

  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } catch (_) {
      throw PreferencesException();
    }
  }
}
