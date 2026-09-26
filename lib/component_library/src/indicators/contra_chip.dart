import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/spacing.dart';

/// A selectable pill. Selected is filled with the accent, unselected is the
/// surface colour; both keep the border.
class ContraChip extends StatelessWidget {
  const ContraChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final ink = selected ? theme.onAccentColor : theme.onSurfaceColor;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.small,
          ),
          decoration: theme.boxDecoration(
            color: selected ? theme.accentColor : theme.surfaceColor,
            radius: Spacing.xLarge,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: Spacing.mediumLarge, color: ink),
                const SizedBox(width: Spacing.xSmall),
              ],
              Text(label, style: theme.labelTextStyle.copyWith(color: ink)),
            ],
          ),
        ),
      ),
    );
  }
}
