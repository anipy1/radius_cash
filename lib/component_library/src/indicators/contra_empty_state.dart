import 'package:flutter/material.dart';

import '../buttons/contra_button.dart';
import '../theme/app_theme.dart';
import '../theme/spacing.dart';

/// Nothing here yet, said kindly: an icon, a title, a line of body text and
/// an optional thing to do about it.
class ContraEmptyState extends StatelessWidget {
  const ContraEmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.illustration,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;

  /// Shown instead of the icon box when given, for example a [ContraPeep].
  final Widget? illustration;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.screenMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            illustration ??
                Container(
                  width: Spacing.xxxLarge,
                  height: Spacing.xxxLarge,
                  alignment: Alignment.center,
                  decoration: theme.boxDecoration(
                    color: theme.highlightColor,
                    raised: true,
                  ),
                  child: Icon(
                    icon,
                    size: Spacing.xLarge,
                    color: theme.onSurfaceColor,
                  ),
                ),
            const SizedBox(height: Spacing.large),
            Text(
              title,
              style: theme.subtitleTextStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.small),
            Text(
              body,
              style: theme.bodyTextStyle.copyWith(color: theme.mutedColor),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: Spacing.large),
              ContraButton.primary(
                label: actionLabel!,
                onPressed: onAction,
                expanded: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
