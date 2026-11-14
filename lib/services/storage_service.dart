// SERVICES: the only code that talks to the outside world.
// This one reads and writes the phone's local storage. Everything stays
// on the device (NFR01). It contains no rules, only load and save.
//
// Three separate boxes, so the background check can update the flags
// without overwriting settings the user is changing at the same time:
//   settings   what the user chose (apps, goals, switches)
//   flags      which warnings were already shown today
//   summaries  minutes per monitored app for recent past days

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/day_flags.dart';

/// Day key ("2026-11-14") -> package name -> minutes.
typedef Summaries = Map<String, Map<String, int>>;

abstract class StorageService {
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);

  Future<DayFlags?> loadFlags();
  Future<void> saveFlags(DayFlags flags);

  Future<Summaries> loadSummaries();
  Future<void> saveSummaries(Summaries summaries);
}

class PrefsStorageService implements StorageService {
  static const _settingsKey = 'sudoq.settings.v1';
  static const _flagsKey = 'sudoq.flags.v1';
  static const _summariesKey = 'sudoq.summaries.v1';

  // The "async" flavour always reads from disk, so the open app and the
  // background check never see each other's stale copies.
  final _prefs = SharedPreferencesAsync();

  Future<Map<String, dynamic>?> _read(String key) async {
    try {
      final text = await _prefs.getString(key);
      if (text == null) return null;
      return Map<String, dynamic>.from(jsonDecode(text) as Map);
    } catch (_) {
      return null; // unreadable data is treated as "nothing saved"
    }
  }

  @override
  Future<AppSettings> loadSettings() async {
    final json = await _read(_settingsKey);
    return json == null ? AppSettings() : AppSettings.fromJson(json);
  }

  @override
  Future<void> saveSettings(AppSettings settings) =>
      _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));

  @override
  Future<DayFlags?> loadFlags() async {
    final json = await _read(_flagsKey);
    return json == null ? null : DayFlags.fromJson(json);
  }

  @override
  Future<void> saveFlags(DayFlags flags) =>
      _prefs.setString(_flagsKey, jsonEncode(flags.toJson()));

  @override
  Future<Summaries> loadSummaries() async {
    final json = await _read(_summariesKey);
    if (json == null) return {};
    return {
      for (final day in json.entries)
        day.key: {
          for (final app in (day.value as Map).entries)
            app.key as String: (app.value as num).toInt(),
        },
    };
  }

  @override
  Future<void> saveSummaries(Summaries summaries) =>
      _prefs.setString(_summariesKey, jsonEncode(summaries));
}
