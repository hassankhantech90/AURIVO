import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';

/// Single-character OTP input row for verification flows.
class OtpTextField extends StatelessWidget {
  const OtpTextField({
    super.key,
    this.length = 6,
    this.onChanged,
    this.errorText,
  });

  final int length;
  final ValueChanged<String>? onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final values = List<String>.filled(length, '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(length, (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == length - 1 ? 0 : AppSpacing.sm,
                ),
                child: TextField(
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  decoration: InputDecoration(
                    counterText: '',
                    errorText: null,
                    enabledBorder: AppBorders.input(
                      side: errorText == null
                          ? AppBorders.subtle
                          : AppBorders.error,
                    ),
                  ),
                  onChanged: (value) {
                    values[index] = value;
                    onChanged?.call(values.join());
                    if (value.isNotEmpty) {
                      FocusScope.of(context).nextFocus();
                    }
                  },
                ),
              ),
            );
          }),
        ),
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            errorText!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}
