final RegExp _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[A-Za-z]{2,}$');

bool isValidEmail(String email) => _emailRegex.hasMatch(email.trim());

/// Returns an error message for the given email, or null if it's valid.
/// Returns null (no error) for an empty string so fields don't show an
/// error before the user has typed anything.
String? emailErrorText(String email) {
  final trimmed = email.trim();
  if (trimmed.isEmpty) return null;
  if (!isValidEmail(trimmed)) return 'Enter a valid email address';
  return null;
}
