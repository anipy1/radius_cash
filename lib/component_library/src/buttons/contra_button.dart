import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/spacing.dart';
import '../theme/tone.dart';

enum ContraButtonSize { large, medium, small }

/// The kit's button: a bordered slab with a hard shadow that presses flat.
///
/// Named constructors instead of flags. `primary` is the filled accent,
/// `secondary` the surface-coloured one, `tonal` any colour family, and
/// `inProgress` swaps the label for a spinner and stops taking taps.
class ContraButton extends StatefulWidget {
  const ContraButton.primary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = ContraButtonSize.large,
    this.expanded = true,
    super.key,
  }) : tone = Tone.accent,
       inProgress = false;

  const ContraButton.secondary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = ContraButtonSize.large,
    this.expanded = true,
    super.key,
  }) : tone = Tone.neutral,
       inProgress = false;

  const ContraButton.tonal({
    required this.label,
    required this.onPressed,
    required this.tone,
    this.icon,
    this.size = ContraButtonSize.large,
    this.expanded = true,
    super.key,
  }) : inProgress = false;

  const ContraButton.inProgress({
    required this.label,
    this.size = ContraButtonSize.large,
    this.expanded = true,
    super.key,
  }) : onPressed = null,
       icon = null,
       tone = Tone.accent,
       inProgress = true;

  final String label;

  /// Null disables the button, drawn flat and muted.
  final VoidCallback? onPressed;
  final IconData? icon;
  final Tone tone;
  final ContraButtonSize size;

  /// Fill the width available, which is what the kit does on phones.
  final bool expanded;
  final bool inProgress;

  @override
  State<ContraButton> createState() => _ContraButtonState();
}

class _ContraButtonState extends State<ContraButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.inProgress;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final fill = _enabled ? theme.colorOf(widget.tone) : theme.dividerColor;
    final ink = _enabled ? theme.onColorOf(widget.tone) : theme.mutedColor;
    final raised = _enabled && !_pressed;

    final (padding, textStyle, iconSize) = switch (widget.size) {
      ContraButtonSize.large => (
        const EdgeInsets.symmetric(
          horizontal: Spacing.large,
          vertical: Spacing.mediumLarge,
        ),
        theme.buttonTextStyle,
        Spacing.large,
      ),
      ContraButtonSize.medium => (
        const EdgeInsets.symmetric(
          horizontal: Spacing.mediumLarge,
          vertical: Spacing.medium,
        ),
        theme.bodyStrongTextStyle,
        Spacing.large,
      ),
      ContraButtonSize.small => (
        const EdgeInsets.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.small,
        ),
        theme.labelTextStyle,
        Spacing.mediumLarge,
      ),
    };

    final content = Row(
      mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.inProgress)
          SizedBox.square(
            dimension: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: theme.borderWidth,
              color: ink,
            ),
          )
        else ...[
          if (widget.icon != null) ...[
            Icon(widget.icon, size: iconSize, color: ink),
            const SizedBox(width: Spacing.small),
          ],
          Text(widget.label, style: textStyle.copyWith(color: ink)),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: _enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          // Pressing moves the slab down onto its own shadow.
          transform: Matrix4.translationValues(
            0,
            raised ? 0 : theme.hardShadow.offset.dy,
            0,
          ),
          padding: padding,
          decoration: theme.boxDecoration(color: fill, raised: raised),
          child: content,
        ),
      ),
    );
  }
}
