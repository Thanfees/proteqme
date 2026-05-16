class PhoneValidator {
  const PhoneValidator._();

  static final RegExp _pattern = RegExp(r'^\+?\d+$');

  static bool isValid(String input) {
    final text = input.trim();
    return text.isNotEmpty && _pattern.hasMatch(text);
  }
}
