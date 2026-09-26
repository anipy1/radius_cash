import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/spacing.dart';
import '../theme/tone.dart';

/// A bordered circle with a short label in it.
///
/// There are no profile pictures on a mesh; a peer is its four character id.
/// The colour is picked from the id so the same peer always looks the same.
class ContraAvatar extends StatelessWidget {
  const ContraAvatar({
    required this.label,
    this.dimension = Spacing.xxLarge,
    super.key,
  });

  final String label;
  final double dimension;

  static const _tones = [
    Tone.accent,
    Tone.success,
    Tone.warning,
    Tone.danger,
    Tone.highlight,
  ];

  @visibleForTesting
  static Tone toneFor(String label) =>
      _tones[label.codeUnits.fold(0, (a, b) => a + b) % _tones.length];

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final tone = toneFor(label);
    return Container(
      width: dimension,
      height: dimension,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.tintOf(tone),
        shape: BoxShape.circle,
        border: theme.border,
      ),
      // Scaled to fit, so a four character label stays one line in a small
      // circle instead of wrapping into two.
      padding: EdgeInsets.all(dimension / 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: theme.labelTextStyle.copyWith(color: theme.onSurfaceColor),
        ),
      ),
    );
  }
}
