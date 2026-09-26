import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/spacing.dart';

/// The kit's switch: a bordered track, filled yellow when on, with a bordered
/// knob that slides.
class ContraToggle extends StatelessWidget {
  const ContraToggle({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  static const _width = 60.0;
  static const _height = 36.0;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final enabled = onChanged != null;
    final knob = _height - theme.borderWidth * 2;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: _width,
          height: _height,
          decoration: BoxDecoration(
            color: value ? theme.warningColor : theme.surfaceColor,
            border: theme.border,
            borderRadius: BorderRadius.circular(_height),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: knob,
            height: knob,
            decoration: BoxDecoration(
              color: theme.surfaceColor,
              shape: BoxShape.circle,
              border: theme.border,
            ),
            alignment: Alignment.center,
            child: Container(
              width: Spacing.medium,
              height: Spacing.medium,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: theme.border,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
