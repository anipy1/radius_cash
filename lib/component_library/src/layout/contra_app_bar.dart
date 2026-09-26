import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/spacing.dart';

/// A flat app bar with the title in the kit's heading weight and a rule
/// underneath instead of a shadow.
class ContraAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ContraAppBar({
    required this.title,
    this.leading,
    this.actions = const [],
    super.key,
  });

  final String title;
  final Widget? leading;
  final List<Widget> actions;

  static const height = 64.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AppBar(
      title: Text(title, style: theme.subtitleTextStyle),
      leading: leading,
      automaticallyImplyLeading: leading != null,
      centerTitle: false,
      toolbarHeight: height,
      backgroundColor: theme.backgroundColor,
      foregroundColor: theme.onSurfaceColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: theme.screenMargin,
      actions: [
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.only(right: Spacing.small),
            child: action,
          ),
        SizedBox(width: theme.screenMargin - Spacing.small),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(theme.borderWidth),
        child: Container(height: theme.borderWidth, color: theme.borderColor),
      ),
    );
  }
}
