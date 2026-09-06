/// A collection of common validation logic for JonkStore POS.
class AppValidators {
  /// Validates that the input is not empty.
  static String? required(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'Field'} is required';
    }
    return null;
  }

  /// Validates that the input is a valid email address.
  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Validates that the password meets minimum security requirements.
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Validates that the input is a valid number.
  static String? number(String? value, [String? fieldName]) {
    if (value == null || value.isEmpty) return '${fieldName ?? 'Field'} is required';
    if (double.tryParse(value) == null) {
      return 'Enter a valid number';
    }
    return null;
  }

  /// Validates that the input is a valid phone number.
  static String? phone(String? value) {
    if (value == null || value.isEmpty) return 'Phone number is required';
    final phoneRegex = RegExp(r'^\+?[\d\s-]{10,}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Enter a valid phone number';
    }
    return null;
  }
}
