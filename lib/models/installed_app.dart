// MODELS: plain data only. No Android calls, no UI, no rules.

/// An app installed on the phone that the user could choose to monitor.
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.name,
    required this.suggested,
  });

  final String packageName;
  final String name;

  /// True for entertainment and social apps, which are listed by default.
  /// Calls, messaging and everything else only appear under "Show all apps".
  final bool suggested;
}
