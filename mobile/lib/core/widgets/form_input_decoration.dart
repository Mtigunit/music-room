import 'package:flutter/material.dart';

/// Builds a standard InputDecoration for form fields across the app
class FormInputDecoration {
  const FormInputDecoration._();

  static InputDecoration build(
    ThemeData theme, {
    required String? labelText,
    required String? hintText,
    Widget? suffixIcon,
    String? errorText,
  }) {
    final colorScheme = theme.colorScheme;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      filled: true,
      fillColor: colorScheme.surface,
      suffixIcon: suffixIcon,
      errorText: errorText,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }
}
