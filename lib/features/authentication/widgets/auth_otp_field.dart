import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/design_system.dart';

/// Six-digit OTP entry widget with autofocus and paste support.
class AuthOtpField extends StatefulWidget {
  const AuthOtpField({
    super.key,
    required this.onChanged,
    this.hasError = false,
  });

  final ValueChanged<String> onChanged;
  final bool hasError;

  @override
  State<AuthOtpField> createState() => _AuthOtpFieldState();
}

class _AuthOtpFieldState extends State<AuthOtpField> {
  static const _otpLength = 6;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes.first.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_otpLength, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == _otpLength - 1 ? 0 : AppSpacing.sm,
            ),
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              autofocus: index == 0,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              textInputAction: index == _otpLength - 1
                  ? TextInputAction.done
                  : TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: _otpLength,
              style: Theme.of(context).textTheme.titleLarge,
              decoration: InputDecoration(
                counterText: '',
                enabledBorder: AppBorders.input(
                  side: widget.hasError ? AppBorders.error : AppBorders.subtle,
                ),
                focusedBorder: AppBorders.input(
                  side: BorderSide(
                    color: widget.hasError
                        ? AppColors.error
                        : AppColors.primaryGold,
                    width: 1.4,
                  ),
                ),
              ),
              onChanged: (value) => _handleChange(index, value),
            ),
          ),
        );
      }),
    );
  }

  void _handleChange(int index, String value) {
    if (value.length > 1) {
      _applyPastedCode(value);
      return;
    }

    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    widget.onChanged(_controllers.map((controller) => controller.text).join());
  }

  void _applyPastedCode(String value) {
    final digits = value
        .replaceAll(RegExp(r'\D'), '')
        .split('')
        .take(_otpLength)
        .toList();
    for (var index = 0; index < _otpLength; index++) {
      _controllers[index].text = index < digits.length ? digits[index] : '';
    }
    if (digits.length == _otpLength) {
      _focusNodes.last.requestFocus();
    }
    widget.onChanged(_controllers.map((controller) => controller.text).join());
  }
}
