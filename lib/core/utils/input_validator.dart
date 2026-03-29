import '../constants/app_constants.dart';

/// Input validation utilities
class InputValidator {
  // Prevent instantiation
  InputValidator._();

  /// Validate email address
  static String? validateEmail(String? email, {bool required = false}) {
    if (email == null || email.isEmpty) {
      return required ? 'Email is required' : null;
    }
    final regex = RegExp(AppConstants.emailPattern);
    return regex.hasMatch(email) ? null : 'Invalid email address';
  }

  /// Validate phone number
  static String? validatePhone(String? phone, {bool required = false}) {
    if (phone == null || phone.isEmpty) {
      return required ? 'Phone number is required' : null;
    }
    final regex = RegExp(AppConstants.phonePattern);
    return regex.hasMatch(phone) ? null : 'Invalid phone number (min 10 digits)';
  }

  /// Validate date in YYYY-MM-DD format
  static String? validateDate(String? date, {bool required = false}) {
    if (date == null || date.isEmpty) {
      return required ? 'Date is required' : null;
    }
    final regex = RegExp(AppConstants.datePattern);
    if (!regex.hasMatch(date)) {
      return 'Invalid date format (use YYYY-MM-DD)';
    }
    try {
      DateTime.parse(date);
      return null;
    } catch (e) {
      return 'Invalid date';
    }
  }

  /// Validate text field (non-empty)
  static String? validateText(String? text, {bool required = true, int minLength = 1}) {
    if (text == null || text.isEmpty) {
      return required ? 'This field is required' : null;
    }
    if (text.length < minLength) {
      return 'Minimum $minLength characters required';
    }
    return null;
  }

  /// Validate name (letters and spaces only)
  static String? validateName(String? name, {bool required = true}) {
    if (name == null || name.isEmpty) {
      return required ? 'Name is required' : null;
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(name)) {
      return 'Name can only contain letters and spaces';
    }
    return null;
  }

  /// Validate URL
  static String? validateUrl(String? url, {bool required = false}) {
    if (url == null || url.isEmpty) {
      return required ? 'URL is required' : null;
    }
    try {
      Uri.parse(url);
      return null;
    } catch (e) {
      return 'Invalid URL format';
    }
  }

  /// Check if string is numeric
  static bool isNumeric(String? str) {
    if (str == null || str.isEmpty) return false;
    return double.tryParse(str) != null;
  }

  /// Check if string is alphabetic
  static bool isAlphabetic(String? str) {
    if (str == null || str.isEmpty) return false;
    return RegExp(r'^[a-z A-Z]+$').hasMatch(str);
  }

  /// Sanitize string input (remove special characters)
  static String sanitizeInput(String? input) {
    if (input == null) return '';
    // Remove leading/trailing whitespace and common special characters
    return input.trim().replaceAll(RegExp(r'[^\w\s@.-]'), '');
  }

  /// Validate collection is not empty
  static String? validateNotEmpty<T>(List<T>? list, {bool required = true}) {
    if (list == null || list.isEmpty) {
      return required ? 'At least one item is required' : null;
    }
    return null;
  }
}

/// Extension on String for quick validation
extension StringValidation on String {
  /// Check if string is a valid email
  bool get isValidEmail {
    final regex = RegExp(AppConstants.emailPattern);
    return regex.hasMatch(this);
  }

  /// Check if string is a valid phone
  bool get isValidPhone {
    final regex = RegExp(AppConstants.phonePattern);
    return regex.hasMatch(this);
  }

  /// Check if string is empty or only whitespace
  bool get isBlank => isEmpty || trim().isEmpty;

  /// Safely parse to int
  int? tryParseInt() => int.tryParse(this);

  /// Safely parse to double
  double? tryParseDouble() => double.tryParse(this);

  /// Safely parse to bool
  bool? tryParseBool() {
    final lower = toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
    return null;
  }

  /// Capitalize first letter
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  /// Truncate to max length
  String truncate(int maxLength, {String ellipsis = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - ellipsis.length)}$ellipsis';
  }
}

/// Extension on DateTime for formatting
extension DateTimeFormatting on DateTime {
  /// Format as YYYY-MM-DD
  String toDateString() => '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  /// Format as HH:MM:SS
  String toTimeString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';

  /// Format as YYYY-MM-DD HH:MM:SS
  String toDateTimeString() => '${toDateString()} ${toTimeString()}';

  /// Check if date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if date is in the past
  bool get isPast => isBefore(DateTime.now());

  /// Check if date is in the future
  bool get isFuture => isAfter(DateTime.now());

  /// Get days difference from now
  int getDaysDifferenceFromNow() {
    final now = DateTime.now();
    final timeDiff = difference(now);
    return timeDiff.inDays;
  }
}
