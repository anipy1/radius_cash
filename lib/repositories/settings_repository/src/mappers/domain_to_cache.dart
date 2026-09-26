import 'package:radius/domain_models/domain_models.dart';

extension DarkModeDomainToCache on DarkModePreference {
  String toCacheValue() => name;
}
