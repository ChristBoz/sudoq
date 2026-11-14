// MODELS: plain data only. No Android calls, no UI, no rules.

/// Which apps were already warned about today, so that each warning and
/// each limit notice is shown only once per app per day (FR06, FR07).
class DayFlags {
  DayFlags({required this.day, Set<String>? warned, Set<String>? notified})
    : warned = warned ?? {},
      notified = notified ?? {};

  /// The calendar day these flags belong to, e.g. "2026-11-14".
  final String day;

  /// Packages that already got the 80% warning today.
  final Set<String> warned;

  /// Packages that already got the limit-reached notice today.
  final Set<String> notified;

  DayFlags copy() =>
      DayFlags(day: day, warned: {...warned}, notified: {...notified});

  Map<String, dynamic> toJson() => {
    'day': day,
    'warned': warned.toList(),
    'notified': notified.toList(),
  };

  factory DayFlags.fromJson(Map<String, dynamic> json) => DayFlags(
    day: json['day'] as String? ?? '',
    warned: {...(json['warned'] as List? ?? const []).cast<String>()},
    notified: {...(json['notified'] as List? ?? const []).cast<String>()},
  );
}
