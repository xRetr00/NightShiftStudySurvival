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
- Initial XCTest scaffold for alarm and recovery engines
- Additional tests for conflict detection, notification action routing, and dashboard guidance
- Optional chart visualization for weekday completion trends
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

This repository currently contains source files and architecture scaffolding.
To run (Windows-first + future Mac):
1. Keep developing code on Windows using your Swift toolchain and repository structure.
2. Use the included XcodeGen spec file project.yml.
3. When Mac is available, run xcodegen generate at repository root to produce the Xcode project.
4. Open generated .xcodeproj in Xcode, ensure iOS 17+ target, and build/run.
5. GitHub Actions workflow .github/workflows/ios-ci.yml already runs macOS simulator tests.

## Next Steps (Implementation Continuation)

1. Add richer historical charting for sleep adherence over time (not only weekday completion).
2. Add import safety controls refinements: block-level preview and conflict warnings before apply.
3. Expand tests for AppNotificationDelegate transition handling with mocked notification payloads.
4. Add packaged alarm audio asset files for each sound style and profile.
5. Add one-command Windows helper script to validate export/import JSON and show preview.
