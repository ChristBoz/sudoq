# suDOq

Screen-time awareness for students: see how long you spend in the apps
you choose, set your own daily goals, and take a short Sudoku break when
you reach one. Android only. Everything stays on the phone.

GIN528 project by Christ Boziikian and Carlos Harb.

## Run it

```
flutter run          # on a connected Android phone
flutter test         # automatic tests, no phone needed
```

Manual test script and results log: [TESTING.md](TESTING.md).

## How the code is organised

Each folder has one job and only uses the folders below it. When
something goes wrong, the kind of problem tells you where to look.

```
lib/
  main.dart            starts the app, refreshes when it comes to the front
  navigation.dart      opens screens for warnings and notification taps
  screens/             what the user sees; no rules, no Android
  widgets/             small reusable UI pieces
  state/app_state.dart what is currently true; the only thing screens talk to
  services/            the outside world
    usage_service.dart         Android usage data (through the Kotlin bridge)
    storage_service.dart       saving and loading on the phone
    notification_service.dart  Android notifications
    background_service.dart    the check that runs while the app is closed
    usage_monitor.dart         read usage + apply the rules (used by app and background)
  logic/               the rules, in plain Dart, fully unit-tested
    threshold_logic.dart       when 80% and 100% fire
    usage_check.dart           the rule applied to every monitored app
    day_rollover.dart          local midnight, once-per-day reset
    goal_validation.dart       what counts as a valid goal
    goal_suggestion.dart       the optional suggested goal
    app_filter.dart            which apps are offered by default
    sudoku_game.dart           4 x 4 puzzle rules
  models/              plain data shapes

packages/sudoq_usage/  the Kotlin bridge (a small local Flutter plugin)
  android/.../SudoqUsagePlugin.kt   routes calls from Flutter
  android/.../UsageReader.kt        permission check + foreground time per app
  android/.../AppLister.kt          installed apps
  lib/sudoq_usage.dart              Dart side of the bridge
```

| Symptom | Look in |
|---|---|
| Minutes differ from Digital Wellbeing, or permission is not detected | `packages/sudoq_usage` (Kotlin), then `services/usage_service.dart` |
| A warning fires at the wrong time, twice, or not at all | `logic/threshold_logic.dart`, `logic/usage_check.dart` |
| Warnings do not reset the next day | `logic/day_rollover.dart` |
| Something is not remembered after closing the app | `services/storage_service.dart` |
| No notification while the app is closed | `services/background_service.dart`, `services/notification_service.dart` |
| The data is right but the screen is wrong or does not update | `screens/`, `widgets/`, then `state/app_state.dart` |

## Known limits

- **Notices can be late.** Android runs the background check about every
  15 minutes at best, and battery saving can delay it further. The app
  also checks every time it is opened.
- **No blocking.** suDOq reminds; it does not lock other apps. Finishing
  the Sudoku does not grant extra time.
- **Usage needs "Usage access".** Without it the app says usage data is
  unavailable and shows a dash, never 0 minutes.
- **Demo mode** (Settings) adds labelled simulated minutes for
  demonstrations. It is not real usage.

## Build note

`android/app/build.gradle.kts` pins `ndkVersion` to the NDK installed on
the development machine, and `shared_preferences_android` is held below
2.5.0. Both avoid a large NDK download; neither affects the app.
