import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radius/component_library/component_library.dart';

void main() {
  Widget host(ThemeData material, void Function(AppThemeData) onTheme) =>
      AppTheme(
        lightTheme: LightAppThemeData(),
        darkTheme: DarkAppThemeData(),
        child: MaterialApp(
          theme: material,
          home: Builder(
            builder: (context) {
              onTheme(AppTheme.of(context));
              return const SizedBox.shrink();
            },
          ),
        ),
      );

  testWidgets('material brightness picks the app theme', (tester) async {
    AppThemeData? seen;
    await tester.pumpWidget(
      host(ThemeData(brightness: Brightness.dark), (t) => seen = t),
    );
    expect(seen, isA<DarkAppThemeData>());

    await tester.pumpWidget(
      host(ThemeData(brightness: Brightness.light), (t) => seen = t),
    );
    // MaterialApp animates between themes, so the switch is not immediate.
    await tester.pumpAndSettle();
    expect(seen, isA<LightAppThemeData>());
  });

  test('the kit shape: two pixel border, hard shadow, Montserrat', () {
    final theme = LightAppThemeData();
    expect(theme.borderWidth, 2);
    expect(theme.hardShadow.blurRadius, 0);
    expect(theme.hardShadow.offset, const Offset(0, 4));
    expect(theme.headingTextStyle.fontFamily, 'Montserrat');
    expect(theme.headingTextStyle.fontWeight, FontWeight.w800);
  });
}
