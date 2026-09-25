// Allows multi-part domains such as school.edu.ph or yahoo.com.ph.
final RegExp _emailRegex = RegExp(r'^[\w.+-]+@([\w-]+\.)+[A-Za-z]{2,}$');

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

/// Usernames are stored lowercased as the document id in /usernames, so the
/// character set is kept deliberately narrow — no spaces, no '@' (which
/// would make it ambiguous with an email at login), and nothing Firestore
/// treats specially in a document path.
final RegExp _usernameRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9_.]{2,19}$');

bool isValidUsername(String username) =>
    _usernameRegex.hasMatch(username.trim());

/// Returns an error message for the given username, or null if it's valid.
String? usernameErrorText(String username) {
  final trimmed = username.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.length < 3) return 'Username must be at least 3 characters';
  if (trimmed.length > 20) return 'Username must be 20 characters or fewer';
  if (!isValidUsername(trimmed)) {
    return 'Use letters, numbers, . or _ — and start with a letter';
  }
  return null;
}
