import 'package:radius/domain_models/domain_models.dart';

extension DarkModeCacheToDomain on String? {
  /// A value this build does not know, or none at all, is the default.
  DarkModePreference toDarkModePreference() =>
      DarkModePreference.values.cast<DarkModePreference?>().firstWhere(
        (p) => p!.name == this,
        orElse: () => null,
      ) ??
      DarkModePreference.alwaysLight;
}
