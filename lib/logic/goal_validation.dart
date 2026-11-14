// LOGIC: pure Dart rules. No Flutter, no Android, no storage.

/// Checks the text typed into the goal editor (AC05).
///
/// Returns an error message to show, or null when the text is a valid goal.
/// Rejects empty text, non-numeric text, 0 and negative numbers.
String? validateLimit(String? text) {
  final value = int.tryParse((text ?? '').trim());
  if (value == null) return 'Enter a whole number of minutes';
  if (value <= 0) return 'The limit must be greater than 0';
  return null;
}
