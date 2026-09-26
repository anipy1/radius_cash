import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/spacing.dart';
import '../theme/tone.dart';

/// A bordered panel. The kit paints cards in the pale member of a colour
/// family, so a card takes a [Tone] and shows its tint.
class ContraCard extends StatelessWidget {
  const ContraCard({
    required this.child,
    this.tone = Tone.neutral,
    this.raised = true,
    this.onTap,
    this.padding = const EdgeInsets.all(Spacing.mediumLarge),
    super.key,
  });

  final Widget child;
  final Tone tone;
  final bool raised;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final card = Container(
      padding: padding,
      decoration: theme.boxDecoration(
        color: tone == Tone.neutral ? theme.surfaceColor : theme.tintOf(tone),
        raised: raised,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}
