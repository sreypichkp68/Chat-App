import 'package:get/get.dart';

class AppValidators {
  // Name validator
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required'.tr;
    }
    return null;
  }

  // Email validator using GetX's built-in email checker
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required'.tr;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address'.tr;
    }
    return null;
  }

  // Password validator
  static String? validatePassword(String? value) {
    if (value == null || value.length < 6) {
      return 'Password must be at least 6 characters long'.tr;
    }
    return null;
  }
}
