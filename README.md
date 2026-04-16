# NightShift Study Survival

Private, offline-first iOS app for one student managing night shifts (22:00-05:00) and university classes.

## Current Implementation Status

Phase 1 + Phase 2 + Phase 3 foundation is in place:
- SwiftData domain models
- Seeded timetable for Monday-Thursday
- Attendance modes (DVZ / DM / Normal)
- Strict alarm finite state machine with timed escalations
- Fallback local notification checkpoints
- Transition telemetry logging
- Live active alarm session flow with Math Lock challenge runtime
- Conflict detection and attendance-priority auto-resolution
- Timetable class CRUD (add/edit/delete) workflow
- Sleep block adherence tracking (followed vs ignored)
- Trend analytics (weekday completion and drift)
- Adaptive recovery logic with extra customization settings
- Notification action routing (snooze/dismiss/math-lock open)
- Local JSON export from Settings for personal backup
- Local JSON import/restore flow from Settings
- Alarm feedback execution service (state-driven audio+haptics loop)
- Packaged alarm sound assets for Default/Siren/Industrial styles across all state profiles
- Manual loud alarm sound pack integrated with daily auto-rotation for work alarms only
- Packaged app branding assets (Logo + AppIcon asset catalog)
- Initial XCTest scaffold for alarm and recovery engines
- Additional tests for conflict detection, notification action routing, dashboard guidance, and notification delegate mock transition handling
- Optional chart visualization for weekday completion trends
- Rich historical sleep adherence chart (daily follow rate history)
- Core screens: Dashboard, Timetable, Alarm Center, Sleep Plan, Subject Settings, Statistics, Settings

## Folder Structure

- NightShiftStudySurvival/App
- NightShiftStudySurvival/Models
- NightShiftStudySurvival/Engines
- NightShiftStudySurvival/Services
- NightShiftStudySurvival/ViewModels
- NightShiftStudySurvival/Views
- NightShiftStudySurvival/Theme
- NightShiftStudySurvival/Seed
- NightShiftStudySurvival/Resources (Sounds + Assets.xcassets)
- scripts (asset generation + macOS setup/build/test)

## Alarm State Machine

Defined explicit states:
- PreAlarm (2m)
- MainAlarm (3m)
- Escalation1 (2m)
- Escalation2 (2m)
- Emergency (until resolved)
- MathLock (blocking for work/emergency alarms)
- Completion
- FailureMissed

Core behavior:
- Timed transition path is deterministic.
- Work and final emergency alarms require Math Lock to complete.
- Fallback notifications are pre-scheduled if app is not opened:
  - T+2m Main fallback
  - T+5m Escalation1 fallback
  - T+9m Emergency fallback
  - T+15m Missed checkpoint
- Critical missed work alarm retries at +5m and +10m.

## Seeded Timetable

Included exactly as requested, with overlap preserved on Wednesday:
- CE102 13:50-16:10
- ING122 15:30-17:00

Friday-Sunday are empty by default (Recovery days).

## Build Notes

This repository is now ready for both Windows development and Mac build handoff.

### CI Bug Fix Summary

- Root cause from CI logs: XcodeGen generated a newer project format, but CI used Xcode 15.4, causing "future project format (77)" failure.
- Fix applied: CI now runs on macos-15 and explicitly selects latest available Xcode (prefers Xcode 26.x), then runs generation/build/test with that toolchain.
- Result: Generated project format and CI Xcode are now aligned.

Latest follow-up fix from new logs:
- Root cause: `select_xcode.sh` was run as a subprocess, so `DEVELOPER_DIR` export did not persist to the calling shell. As a result, build commands still used Xcode 16.4.
- Additional failure: targets were missing generated Info.plist configuration, which blocked test builds with code-sign/Info.plist errors.
- Fix applied: workflow/scripts now set `DEVELOPER_DIR` directly in the active shell and project.yml now enables `GENERATE_INFOPLIST_FILE: YES` for app and tests.

### Windows

1. Continue coding in this repo from Windows as before.
2. Regenerate local sounds/icons anytime with:
  - pwsh -File scripts/generate_assets.ps1
3. Replace sounds from your manual pack by copying files to:
  - NightShiftStudySurvival/Resources/Sounds
  and naming them to match app keys (alarm_... and web_...)
4. Validate backup JSON and preview import counts/warnings with:
  - pwsh -File scripts/windows_import_preview.ps1 -JsonPath path\\to\\backup.json

### Mac

1. Install Xcode from App Store, open it once, and accept any license prompts.
2. Install Homebrew (if needed):
  - /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
3. From repository root run:
  - make setup
4. Open NightShiftStudySurvival.xcodeproj in Xcode, choose a simulator/device, then run.

### Quick Commands (Mac)

- make project  -> regenerate Xcode project
- make build    -> simulator build
- make test     -> simulator tests
- make web-sounds -> optional helper download (not required if using manual sound pack)

### Version Targets Used

- CI runner: macos-15
- Preferred CI Xcode: latest installed Xcode 26.x (fallback to 16.x if 26.x not found)
- Project deployment target: iOS 26.0
- Swift language mode: Swift 6.0
- CI simulator destination: iPhone 17

### Docs Reference Used For Version Alignment

- Apple Xcode release/support matrix: https://developer.apple.com/support/xcode/
- GitHub Actions runner images software matrix:
  - https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md
  - https://github.com/actions/runner-images/blob/main/images/macos/macos-14-arm64-Readme.md
- XcodeGen project spec/options reference:
  - https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md

### CI

- GitHub Actions workflow at .github/workflows/ios-ci.yml builds/tests on macOS automatically.

## Completed Backlog

The previously listed implementation continuation steps are completed:
1. Rich historical charting for sleep adherence over time.
2. Import safety refinements with block-level preview and overlap conflict warnings.
3. Expanded AppNotificationDelegate integration tests using mocked payload handling.
4. In-app alarm preview player in Settings.
5. One-command Windows import preview helper script.

## Alarm Sound Behavior (Current)

- App theme is forced to Dark mode.
- Work alarms and Final Emergency alarms use loud web-downloaded sounds only.
- The web work-alarm sound rotates automatically by day (daily variation).
- Non-work alarms continue to use the user-selected local style and loudness profile.
