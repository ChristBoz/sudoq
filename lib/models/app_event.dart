// MODELS: plain data only. No Android calls, no UI, no rules.

/// What crossing a usage threshold should trigger.
enum AppEvent {
  /// Nothing to show.
  none,

  /// Usage reached 80% of the daily goal (FR06).
  warning80,

  /// Usage reached 100% of the daily goal (FR07).
  limitReached,
}
