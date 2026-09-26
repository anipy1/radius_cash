import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/spacing.dart';

/// One bordered row: something on the left, two lines of text, something on
/// the right. Used for peers, bounties, settings, anything in a list.
class ContraListTile extends StatelessWidget {
  const ContraListTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final row = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.mediumLarge,
        vertical: Spacing.medium,
      ),
      decoration: theme.boxDecoration(color: theme.surfaceColor),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: Spacing.medium),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.bodyStrongTextStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.smallTextStyle.copyWith(
                      color: theme.mutedColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Spacing.medium),
            trailing!,
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(onTap: onTap, child: row);
  }
}
