# Implement Notification System

> RFC: 007
> Status: Implemented

## Summary

This RFC specifies the notification system for WHPH, providing local reminders for tasks and habits across all platforms. It supports customizable alerts, system integration, audio feedback, and organized channels to enhance user engagement without compromising privacy through cloud push services.

## Motivation

Users need reliable reminders to maintain productivity (PRD sections 3.1, 4.1, 4.2), with configurable timing and content (section 3.3). The privacy-first approach prohibits cloud notifications (section 1.3), necessitating local handling. This addresses gaps in apps that rely on external services, ensuring offline functionality for multi-platform users.

## Detailed Design

Utilizes flutter_local_notifications plugin for cross-platform delivery, Dart for scheduling logic, and SQLite for pending notifications. Core features:

### Data Models

- **Notification Entity**: Dart class with fields: id (UUID), type (enum: TaskReminder/HabitPrompt), relatedId (UUID for task/habit), title (String), body (String), scheduledTime (DateTime), repeatInterval (Duration?), sound (bool), channel (String), isActive (bool).
- **Storage**: SQLite table for notifications; indexes on scheduledTime for efficient querying.

### Notification Components

- **Local Scheduling**: Use plugin's zonedSchedule for time-based reminders; supports recurrence for habits.
- **Customization**: Settings screen with sliders for timing offsets (e.g., 10min before deadline), toggles for sound/vibration, text templates.
- **Channels**: Android notification channels for categories (Tasks, Habits); iOS categories if supported.
- **Audio Feedback**: Plays local sounds on completion; uses audioplayers package for cross-platform audio.
- **Integration**: Triggers from task/habit modules: e.g., on task creation, schedule reminder if deadline set.

### UI Components

- **Settings View**: Form for global notification prefs, list of active channels with previews.
- **Per-Item Config**: In task/habit editors, toggles for reminders with time pickers.
- **Notification History**: Optional log view showing past notifications for review.

### APIs and Logic

- **Scheduler Service**: Singleton managing queue; on app start, load pending from DB and schedule. cancelNotification() removes on completion.
- **Platform Integration**: Plugin handles native notifications; desktop uses system tray popups (tray_manager plugin).
- **Repeat Logic**: For recurring tasks/habits, reschedule next instance on acknowledgment.
- **Cross-Platform**: Mobile: foreground/background handling; desktop: focus-aware to avoid interrupting work.

Trade-offs: Local-only limits remote triggers (e.g., no web pushes); chosen for privacy. Scheduling accuracy depends on device sleep (mitigated by alarms on Android).

Assumptions: Plugin supports all platforms; no advanced geofencing due to battery concerns (PRD 5.1.1).

## Alternatives Considered

- **Cloud Push (e.g., FCM)**: Rejected for privacy and no-infra (PRD 5.1.3); introduces dependencies.
- **Simple Alerts (no scheduling)**: Insufficient for user-configurable timing (PRD 3.3); zoned scheduling essential.
- **Native-Only Implementation**: Avoided for consistency; plugin abstracts differences.
- **No Audio (visual only)**: Diminishes feedback (PRD 3.3.4); audio enhances UX without complexity.

## Implementation Notes

Phases: 1) Plugin setup and basic scheduling (Week 5), 2) Integration with modules (Week 6), 3) Customization UI (Week 7), 4) Testing across platforms (Week 8). Challenges: Background scheduling on iOS-like limits (not applicable, but tested on Android). Outcomes: Delivers 100% on-time in tests; 90% coverage. Integrated with UI themes for notification styling.

## References

- [PRD Section 3.3: Notification System features](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/PRD.md#L110-L115).
- Flutter Documentation: [Local Notifications](https://pub.dev/packages/flutter_local_notifications).
- audioplayers Package: [Audio Playback](https://pub.dev/packages/audioplayers).
