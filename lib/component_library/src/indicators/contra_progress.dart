import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The one spinner, in the ink colour, with the kit's line weight.
class ContraProgress extends StatelessWidget {
  const ContraProgress({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Center(
      child: CircularProgressIndicator(
        strokeWidth: theme.borderWidth,
        color: theme.onSurfaceColor,
      ),
    );
  }
}
