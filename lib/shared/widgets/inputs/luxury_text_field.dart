import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';

/// Visual validation state for reusable input fields.
enum AppInputState { normal, error, success }

/// Reusable luxury text field supporting validation, icons, read-only and multiline variants.
class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.prefixIcon,
    this.suffixIcon,
    this.inputState = AppInputState.normal,
    this.validator,
    this.onChanged,
    this.onTap,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final AppInputState inputState;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderSide = switch (inputState) {
      AppInputState.normal => AppBorders.subtle,
      AppInputState.error => AppBorders.error,
      AppInputState.success => AppBorders.success,
    };

    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      readOnly: readOnly,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      validator: validator,
      onChanged: onChanged,
      onTap: onTap,
      // Input fill is always pureWhite (both themes), so entered text must be
      // an on-light color — otherwise the dark TextTheme paints it white-on-
      // white (invisible). charcoal is already the light-mode bodyLarge colour,
      // so light mode is unchanged. Covers Password/Multiline/ReadOnly too.
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(color: AppColors.charcoal),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffixIcon ?? _stateIcon(),
        enabledBorder: AppBorders.input(side: borderSide),
        focusedBorder: AppBorders.input(
          side: BorderSide(color: borderSide.color, width: 1.4),
        ),
      ),
    );
  }

  Widget? _stateIcon() {
    return switch (inputState) {
      AppInputState.normal => null,
      AppInputState.error => const Icon(
        Icons.error_outline,
        color: AppColors.error,
      ),
      AppInputState.success => const Icon(
        Icons.check_circle_outline,
        color: AppColors.success,
      ),
    };
  }
}

/// Password field with built-in visibility toggle and validation states.
class PasswordTextField extends StatefulWidget {
  const PasswordTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.errorText,
    this.validator,
    this.onChanged,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: widget.controller,
      labelText: widget.labelText,
      hintText: widget.hintText,
      errorText: widget.errorText,
      obscureText: _obscure,
      prefixIcon: Icons.lock_outline,
      validator: widget.validator,
      onChanged: widget.onChanged,
      inputState: widget.errorText == null
          ? AppInputState.normal
          : AppInputState.error,
      suffixIcon: IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    );
  }
}

/// Multiline input for notes, descriptions, and longer free-form text.
class MultilineTextField extends StatelessWidget {
  const MultilineTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.validator,
    this.onChanged,
    this.minLines = 4,
    this.maxLines = 8,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? labelText;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      labelText: labelText,
      hintText: hintText,
      minLines: minLines,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
    );
  }
}

/// Read-only input surface for non-editable form values.
class ReadOnlyTextField extends StatelessWidget {
  const ReadOnlyTextField({
    super.key,
    required this.value,
    this.labelText,
    this.onTap,
  });

  final String value;
  final String? labelText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      initialValue: value,
      labelText: labelText,
      readOnly: true,
      onTap: onTap,
      suffixIcon: const Icon(Icons.chevron_right),
    );
  }
}
