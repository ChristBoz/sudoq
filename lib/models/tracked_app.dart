// MODELS: plain data only. No Android calls, no UI, no rules.

/// An app the user chose to monitor, with its daily goal.
class TrackedApp {
  TrackedApp({
    required this.packageName,
    required this.name,
    this.limitMinutes,
  });

  /// Android's unique id for the app, e.g. "com.instagram.android".
  final String packageName;

  /// The name shown to the user, e.g. "Instagram".
  final String name;

  /// Daily goal in minutes. Null = no goal set yet.
  int? limitMinutes;

  Map<String, dynamic> toJson() => {
    'package': packageName,
    'name': name,
    'limit': limitMinutes,
  };

  factory TrackedApp.fromJson(Map<String, dynamic> json) => TrackedApp(
    packageName: json['package'] as String,
    name: json['name'] as String? ?? json['package'] as String,
    limitMinutes: json['limit'] as int?,
  );
}
