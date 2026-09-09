/// Form field validators for authentication screens.
class AuthValidators {
  const AuthValidators._();

  // Pragmatic client-side email check (not full RFC 5322): allows +tags in the
  // local part and modern multi-char TLDs (.online, .studio, .jewelry). Supabase
  // remains the final authority. Shared by email() and emailOrPakistanPhone().
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  static final RegExp _pakistanPhoneRegex = RegExp(r'^(\+92|0)?3\d{9}$');

  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? email(String? value) {
    final requiredError = required(value, fieldName: 'Email');
    if (requiredError != null) {
      return requiredError;
    }

    if (!_emailRegex.hasMatch(value!.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? pakistanPhone(String? value) {
    final requiredError = required(value, fieldName: 'Phone');
    if (requiredError != null) {
      return requiredError;
    }

    final normalized = value!.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (!_pakistanPhoneRegex.hasMatch(normalized)) {
      return 'Enter a valid Pakistan phone number';
    }
    return null;
  }

  static String? emailOrPakistanPhone(String? value) {
    final requiredError = required(value, fieldName: 'Email or phone');
    if (requiredError != null) {
      return requiredError;
    }

    final input = value!.trim();
    final phone = input.replaceAll(RegExp(r'[\s-]'), '');
    if (_emailRegex.hasMatch(input) || _pakistanPhoneRegex.hasMatch(phone)) {
      return null;
    }
    return 'Enter a valid email or Pakistan phone number';
  }

  static String? password(String? value) {
    final requiredError = required(value, fieldName: 'Password');
    if (requiredError != null) {
      return requiredError;
    }

    final password = value!;
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp('[A-Z]').hasMatch(password)) {
      return 'Password must include an uppercase letter';
    }
    if (!RegExp('[a-z]').hasMatch(password)) {
      return 'Password must include a lowercase letter';
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return 'Password must include a number';
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'Password must include a special character';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    final requiredError = required(value, fieldName: 'Confirm password');
    if (requiredError != null) {
      return requiredError;
    }

    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? fullName(String? value) {
    final requiredError = required(value, fieldName: 'Full name');
    if (requiredError != null) {
      return requiredError;
    }

    if (value!.trim().length < 3) {
      return 'Enter your full name';
    }
    return null;
  }

  static String? otp(String value) {
    if (value.length != 6 || !RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'Enter the 6-digit code';
    }
    return null;
  }
}
