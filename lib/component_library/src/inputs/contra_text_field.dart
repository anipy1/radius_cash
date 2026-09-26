import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/spacing.dart';

/// The kit's input: a label above a bordered box, an error line below it.
///
/// Takes the same things a TextField does. Validation belongs to the form
/// field that owns it; this only draws whatever [errorText] it is given.
class ContraTextField extends StatelessWidget {
  const ContraTextField({
    this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.maxLength,
    this.prefixText,
    this.suffixText,
    this.enabled = true,
    this.autofocus = false,
    super.key,
  });

  final String? label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? maxLength;
  final String? prefixText;
  final String? suffixText;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final hasError = errorText != null;
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(theme.cornerRadius),
      borderSide: BorderSide(
        color: hasError ? theme.dangerColor : theme.borderColor,
        width: theme.borderWidth,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: theme.labelTextStyle),
          const SizedBox(height: Spacing.small),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: maxLines,
          maxLength: maxLength,
          enabled: enabled,
          autofocus: autofocus,
          style: theme.bodyTextStyle,
          cursorColor: theme.onSurfaceColor,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: theme.bodyTextStyle.copyWith(color: theme.mutedColor),
            prefixText: prefixText,
            suffixText: suffixText,
            prefixStyle: theme.bodyStrongTextStyle,
            suffixStyle: theme.bodyStrongTextStyle,
            filled: true,
            fillColor: enabled ? theme.surfaceColor : theme.dividerColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Spacing.mediumLarge,
              vertical: Spacing.medium,
            ),
            counterText: '',
            enabledBorder: outline,
            focusedBorder: outline.copyWith(
              borderSide: outline.borderSide.copyWith(
                color: hasError ? theme.dangerColor : theme.accentColor,
              ),
            ),
            disabledBorder: outline,
            errorBorder: outline,
            focusedErrorBorder: outline,
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: Spacing.xSmall),
          Text(
            errorText!,
            style: theme.captionTextStyle.copyWith(color: theme.dangerColor),
          ),
        ],
      ],
    );
  }
}
