import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/spacing.dart';
import '../theme/tone.dart';

/// A small bordered pill with a word in it: a status, a count, an amount.
class ContraBadge extends StatelessWidget {
  const ContraBadge({
    required this.label,
    this.tone = Tone.neutral,
    this.filled = false,
    super.key,
  });

  final String label;
  final Tone tone;

  /// Strong colour with contrasting text, rather than the pale tint.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.xxSmall,
      ),
      decoration: theme.boxDecoration(
        color: filled ? theme.colorOf(tone) : theme.tintOf(tone),
        radius: Spacing.small,
      ),
      child: Text(
        label,
        style: theme.labelTextStyle.copyWith(
          color: filled ? theme.onColorOf(tone) : theme.onSurfaceColor,
        ),
      ),
    );
  }
}
