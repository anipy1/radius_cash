import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radius/component_library/component_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every listed peep exists and parses as SVG', () async {
    for (final asset in PeepAssets.all) {
      final bytes = await rootBundle.load(asset);
      expect(bytes.lengthInBytes, greaterThan(100), reason: asset);
      // Throws on anything the renderer cannot parse.
      await vg.loadPicture(SvgAssetLoader(asset), null);
    }
  });

  test('no two names point at the same file', () {
    expect(PeepAssets.all.toSet().length, PeepAssets.all.length);
  });
}
