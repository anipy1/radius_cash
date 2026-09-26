import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/spacing.dart';

/// Shows [child] in a sheet with the kit's border along its top edge.
///
/// A function rather than a widget, because the thing worth sharing is how
/// the sheet is presented, and a widget cannot present itself.
Future<T?> showContraBottomSheet<T>({
  required BuildContext context,
  required Widget child,
}) {
  final theme = AppTheme.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        border: Border(
          top: BorderSide(color: theme.borderColor, width: theme.borderWidth),
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(theme.cornerRadius),
        ),
      ),
      padding: EdgeInsets.only(
        left: theme.screenMargin,
        right: theme.screenMargin,
        top: Spacing.large,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Spacing.large,
      ),
      child: SafeArea(top: false, child: child),
    ),
  );
}
