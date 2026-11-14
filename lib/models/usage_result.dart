// MODELS: plain data only. No Android calls, no UI, no rules.

/// The answer to "how long was each app used?".
///
/// It is either real data or an explanation of why there is none. This is
/// what keeps "no reading" from ever being shown as "0 minutes" (AC06).
sealed class UsageResult {
  const UsageResult();
}

/// Android returned usage data. Apps missing from [minutes] were not used.
class UsageData extends UsageResult {
  const UsageData(this.minutes);

  /// Package name -> whole minutes in the foreground.
  final Map<String, int> minutes;

  int minutesFor(String packageName) => minutes[packageName] ?? 0;
}

/// There is no usage data to show.
class UsageUnavailable extends UsageResult {
  const UsageUnavailable(this.reason);

  final UsageProblem reason;
}

enum UsageProblem {
  /// The user has not switched on "Usage access" for suDOq.
  noPermission,

  /// Access is on, but Android returned nothing for this period.
  noData,

  /// Reading usage failed (for example, not running on Android).
  error,
}
