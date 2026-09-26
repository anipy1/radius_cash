import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/spacing.dart';

/// A row of labels of which one is chosen. The kit draws it as adjoining
/// bordered cells with the chosen one filled.
class ContraSegmentedControl extends StatelessWidget {
  const ContraSegmentedControl({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  }) : assert(labels.length >= 2, 'a control needs at least two segments');

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final radius = Radius.circular(theme.cornerRadius);
    return Container(
      decoration: theme.boxDecoration(color: theme.surfaceColor),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selectedIndex,
                label: labels[i],
                child: GestureDetector(
                  onTap: () => onSelected(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: Spacing.medium,
                    ),
                    decoration: BoxDecoration(
                      color: i == selectedIndex
                          ? theme.accentColor
                          : theme.surfaceColor,
                      borderRadius: BorderRadius.horizontal(
                        left: i == 0 ? radius : Radius.zero,
                        right: i == labels.length - 1 ? radius : Radius.zero,
                      ),
                      border: i == 0
                          ? null
                          : Border(
                              left: BorderSide(
                                color: theme.borderColor,
                                width: theme.borderWidth,
                              ),
                            ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      labels[i],
                      style: theme.labelTextStyle.copyWith(
                        color: i == selectedIndex
                            ? theme.onAccentColor
                            : theme.onSurfaceColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
