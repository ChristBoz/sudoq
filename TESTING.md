# suDOq testing

Two kinds of tests: automatic ones that run on the computer, and a manual
script that is run on a real phone.

## Automatic tests

```
flutter test
```

| Folder | What it checks |
|---|---|
| `test/logic/` | The rules: thresholds, goal validation, day rollover, goal suggestion, app filter, Sudoku |
| `test/state/` | App behaviour on fake services: readings, warnings, saving, history, demo mode |
| `test/services/` | The background check: which notifications are sent and when |
| `test/widget_test.dart` | The screens end to end: onboarding, selecting apps, goal editor, limit notice, Sudoku |

None of these need a phone. They do not prove that Android returns
correct usage numbers; the manual script below covers that.

## Manual script (one run = steps 1 to 12)

Reference device: ______________________  Android version: ______

Before each run: uninstall suDOq, then install it again (`flutter run`).

| # | Step | Expected | Covers |
|---|---|---|---|
| 1 | Open suDOq | Onboarding explains usage access | FR01 |
| 2 | Tap "Continue without these permissions", pick one app, tap Done | Dashboard shows "Usage data unavailable" and a dash, not 0 | FR01, AC06 |
| 3 | Tap "Grant usage access", switch suDOq on, go back | Notice disappears, minutes are shown | FR01, FR03 |
| 4 | Compare one app's minutes with Digital Wellbeing | Within about 2 minutes of each other | FR03 |
| 5 | Open "Select apps" | Entertainment apps listed; WhatsApp/Phone only after "Show all apps" | FR02 |
| 6 | Unselect every app, go back | "No apps selected yet." with a "Select apps" button | AC07 |
| 7 | Select an app, tap "Set goal", enter 0, then -5, then abc | Saving is blocked with a message each time | AC05 |
| 8 | Enter a goal 5 minutes above today's usage, save | Card shows "used / goal min today" | FR04 |
| 9 | Use that app until 80% of the goal, wait up to 15 min | One "80% of your goal" notification, not repeated | FR06, AC02 |
| 10 | Keep using it past the goal, wait up to 15 min | Notification with Play Sudoku / View usage / Dismiss | FR07, AC01 |
| 11 | Tap "Play Sudoku", try to change a clue, enter a wrong digit, then exit | Puzzle opens; clue stays; conflict is marked and explained; exit works | FR08, AC03 |
| 12 | Back on the dashboard | Usage and goal are unchanged by the puzzle | AC04 |

## Blocking script (the Sudoku gate)

Needs both permissions: "Usage access" and "Display over other apps".
Quick setup: give one app a 1-minute goal and use it for a minute, or
turn on Demo mode and add simulated minutes past the goal.

| # | Step | Expected |
|---|---|---|
| B1 | Dashboard, with "Display over other apps" off | Notice "Sudoku cannot appear over apps" with a button to allow it |
| B2 | Allow it, return to suDOq | Notice disappears; a permanent "suDOq is watching" notification is present |
| B3 | Open an app that is under its goal | Nothing happens |
| B4 | Open an app that is past its goal | Within about a second, "Daily goal reached" with a Sudoku appears |
| B5 | Try the back button | You land on the home screen, not in the app |
| B6 | Open the app again, tap "Leave" | Home screen again |
| B7 | Open the app again, check "Continue" | Disabled until the puzzle is solved |
| B8 | Solve the puzzle, tap "Continue" | The app opens and can be used |
| B9 | Go to the home screen, open the app again | A new, different puzzle appears |
| B10 | While using the app after solving, turn the screen off and on | The app is still usable, no new puzzle |
| B11 | Use an app until it crosses its goal while open | The puzzle appears within about 15 seconds |
| B12 | Settings: switch off "Require Sudoku past the goal" | Apps past their goal open normally |
| B13 | Settings: pause monitoring | Apps past their goal open normally |
| B14 | Restart the phone, do not open suDOq, open the blocked app | The puzzle still appears |
| B15 | Leave the phone unused for an hour, then repeat B4 | The puzzle still appears (the service survived) |

Extra checks (not every run):

| Step | Expected | Covers |
|---|---|---|
| Close suDOq completely and reopen | Apps, goals and switches are still there | Stage 2 |
| Open "Last 7 days" | Minutes per day per app; a dash where there is no data | FR03, US05 |
| Edit a goal after 3+ days of data | A suggested goal is offered and can be ignored | FR05 |
| Settings: pause monitoring | No warnings or notices while paused | FR09 |
| Settings: delete usage history | Past days show dashes; today restarts from now; goals kept | FR09 |
| Turn on airplane mode, repeat steps 8 to 12 | Everything works offline | NFR04 |
| Phone font size at maximum | No cut-off text or buttons | NFR05 |
| Leave the app open past midnight, then use the monitored app | Warnings can fire again the new day | Day rollover |

Demo mode (Settings) adds a "+5 min (simulated)" button to each app card.
It is for demonstrating steps 9 to 12 quickly. Simulated minutes are
labelled on the card and are not real usage.

## Results log

Reliability target: 20 consecutive runs without a crash (NFR06).
Dashboard target: opens within 2 seconds after access is granted (NFR03).

| Run | Date | All steps passed? | Crash? | Dashboard open time | Notes |
|---|---|---|---|---|---|
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |

(continue to 20)

Usability target: at least 4 of 5 testers set a limit and open Sudoku
without help (NFR02).

| Tester | Set a limit unaided? | Opened Sudoku unaided? | Friction points |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |
