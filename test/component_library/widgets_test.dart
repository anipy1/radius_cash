import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radius/component_library/component_library.dart';

Widget host(Widget child) => AppTheme(
  lightTheme: LightAppThemeData(),
  darkTheme: DarkAppThemeData(),
  child: MaterialApp(
    theme: LightAppThemeData().materialThemeData,
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('ContraButton', () {
    testWidgets('taps through and presses flat while held', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(ContraButton.primary(label: 'Go', onPressed: () => taps++)),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Go')),
      );
      await tester.pump();
      var box = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect((box.decoration! as BoxDecoration).boxShadow, isEmpty);

      await gesture.up();
      await tester.pumpAndSettle();
      box = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      expect((box.decoration! as BoxDecoration).boxShadow, hasLength(1));
      expect(taps, 1);
    });

    testWidgets('disabled takes no taps and casts no shadow', (tester) async {
      await tester.pumpWidget(
        host(const ContraButton.primary(label: 'No', onPressed: null)),
      );
      await tester.tap(find.text('No'));
      final box = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect((box.decoration! as BoxDecoration).boxShadow, isEmpty);
    });

    testWidgets('in progress shows a spinner instead of the label', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const ContraButton.inProgress(label: 'Sending')),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sending'), findsNothing);
    });
  });

  testWidgets('ContraIconButton exposes its label to assistive tech', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ContraIconButton(
          icon: Icons.add,
          semanticLabel: 'Add bounty',
          onPressed: () {},
        ),
      ),
    );
    expect(find.bySemanticsLabel('Add bounty'), findsOneWidget);
  });

  testWidgets('ContraCard is tappable only when asked', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(ContraCard(onTap: () => taps++, child: const Text('card'))),
    );
    await tester.tap(find.text('card'));
    expect(taps, 1);

    await tester.pumpWidget(host(const ContraCard(child: Text('flat'))));
    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('ContraListTile lays out title, subtitle and sides', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const ContraListTile(
          leading: Icon(Icons.person),
          title: 'K7QA',
          subtitle: 'in range',
          trailing: Icon(Icons.chevron_right),
        ),
      ),
    );
    expect(find.text('K7QA'), findsOneWidget);
    expect(find.text('in range'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  group('ContraBadge', () {
    testWidgets('filled uses the strong colour, plain the tint', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ContraBadge(label: 'a', tone: Tone.success, filled: true),
              ContraBadge(label: 'b', tone: Tone.success),
            ],
          ),
        ),
      );
      final theme = LightAppThemeData();
      final boxes = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => (c.decoration as BoxDecoration?)?.color)
          .toList();
      expect(boxes, contains(theme.colorOf(Tone.success)));
      expect(boxes, contains(theme.tintOf(Tone.success)));
    });
  });

  testWidgets('ContraAmountBadge drops cents when there are none', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ContraAmountBadge(cents: 2500, symbol: '€'),
            ContraAmountBadge(cents: 1250, symbol: '€'),
          ],
        ),
      ),
    );
    expect(find.text('€25'), findsOneWidget);
    expect(find.text('€12.50'), findsOneWidget);
  });

  testWidgets('ContraChip reports selection', (tester) async {
    var selected = false;
    await tester.pumpWidget(
      host(
        ContraChip(
          label: 'Mine',
          selected: false,
          onSelected: () => selected = true,
        ),
      ),
    );
    await tester.tap(find.text('Mine'));
    expect(selected, isTrue);
  });

  test('ContraAvatar gives the same peer the same colour', () {
    expect(ContraAvatar.toneFor('K7QA'), ContraAvatar.toneFor('K7QA'));
    final tones = {
      for (final l in ['AAAA', 'AAAB', 'AAAC', 'AAAD', 'AAAE'])
        ContraAvatar.toneFor(l),
    };
    expect(tones, hasLength(5));
  });

  testWidgets('ContraEmptyState shows its action only when given one', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const ContraEmptyState(
          icon: Icons.radar,
          title: 'Nobody',
          body: 'Nothing here.',
        ),
      ),
    );
    expect(find.byType(ContraButton), findsNothing);

    var pressed = false;
    await tester.pumpWidget(
      host(
        ContraEmptyState(
          icon: Icons.radar,
          title: 'Nobody',
          body: 'Nothing here.',
          actionLabel: 'Post',
          onAction: () => pressed = true,
        ),
      ),
    );
    await tester.tap(find.text('Post'));
    expect(pressed, isTrue);
  });

  group('ContraTextField', () {
    testWidgets('shows label, forwards input, shows an error', (tester) async {
      String? typed;
      await tester.pumpWidget(
        host(
          ContraTextField(
            label: 'Title',
            hint: 'What?',
            errorText: 'Required',
            onChanged: (v) => typed = v,
          ),
        ),
      );
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'hi');
      expect(typed, 'hi');
    });
  });

  testWidgets('ContraSegmentedControl reports the tapped index', (
    tester,
  ) async {
    int? chosen;
    await tester.pumpWidget(
      host(
        ContraSegmentedControl(
          labels: const ['One', 'Two', 'Three'],
          selectedIndex: 0,
          onSelected: (i) => chosen = i,
        ),
      ),
    );
    await tester.tap(find.text('Three'));
    expect(chosen, 2);
  });

  testWidgets('ContraToggle flips its value', (tester) async {
    bool? next;
    await tester.pumpWidget(
      host(
        ContraToggle(
          value: false,
          onChanged: (v) => next = v,
          semanticLabel: 'Relays',
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Relays'));
    expect(next, isTrue);
  });

  testWidgets('ContraAppBar shows the title and actions', (tester) async {
    await tester.pumpWidget(
      AppTheme(
        lightTheme: LightAppThemeData(),
        darkTheme: DarkAppThemeData(),
        child: MaterialApp(
          theme: LightAppThemeData().materialThemeData,
          home: Scaffold(
            appBar: ContraAppBar(
              title: 'Radius',
              actions: [
                ContraIconButton(
                  icon: Icons.add,
                  semanticLabel: 'Add',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Radius'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('showContraBottomSheet presents and pops', (tester) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => ContraButton.primary(
            label: 'Open',
            onPressed: () => showContraBottomSheet<void>(
              context: context,
              child: const Text('sheet body'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('sheet body'), findsOneWidget);
  });
}
