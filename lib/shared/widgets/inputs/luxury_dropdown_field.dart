import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';

/// Dropdown form field for selecting from typed option lists.
class LuxuryDropdownField<T> extends StatelessWidget {
  const LuxuryDropdownField({
    super.key,
    required this.items,
    required this.itemLabelBuilder,
    this.value,
    this.labelText,
    this.hintText,
    this.errorText,
    this.onChanged,
    this.validator,
  });

  final List<T> items;
  final String Function(T item) itemLabelBuilder;
  final T? value;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabelBuilder(item)),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        errorText: errorText,
        enabledBorder: AppBorders.input(
          side: errorText == null ? AppBorders.subtle : AppBorders.error,
        ),
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
    );
  }
}
