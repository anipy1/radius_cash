import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/spacing.dart';
import '../theme/tone.dart';

/// A square bordered button holding one icon. Same shape as [ContraButton],
/// sized for an app bar or a row end.
class ContraIconButton extends StatelessWidget {
  const ContraIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.tone = Tone.neutral,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Localised by the caller; an icon on its own says nothing to a screen
  /// reader.
  final String semanticLabel;
  final Tone tone;

  static const dimension = Spacing.xxLarge;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: dimension,
          height: dimension,
          decoration: theme.boxDecoration(
            color: enabled ? theme.colorOf(tone) : theme.dividerColor,
            raised: enabled,
            radius: theme.smallCornerRadius,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: Spacing.large,
            color: enabled ? theme.onColorOf(tone) : theme.mutedColor,
          ),
        ),
      ),
    );
  }
}
