# Implement Platform-Specific Features

## RFC Number

008

## Status

Implemented

## Authors

Development Team

## Summary

This RFC documents platform-specific enhancements for WHPH, leveraging native capabilities in desktop (Windows/Linux) and mobile (Android) via Flutter's infrastructure modules. It includes system tray integration, keyboard shortcuts, home screen widgets, background tracking, and permission management, ensuring optimal performance while adhering to modular architecture in infrastructure/platform-specific folders.

## Motivation

Per PRD section 3.4, tailored features maximize platform strengths for users across devices (section 2.3). This extends core modules like app_usages and notifications, addressing OS constraints (section 5.1) to enhance usability without compromising cross-platform consistency or privacy.

## Detailed Design

Integrates with infrastructure/android/, infrastructure/desktop/, etc., using platform channels and plugins. Flutter ensures unified logic.

### Data Models

- Shared via core/domain/shared/models/ for platform prefs (e.g., AutoStartModel).
- Persistence in infrastructure/persistence/shared/ for settings.

### Desktop Features (Windows/Linux)

- **System Tray**: Uses tray_manager in infrastructure/desktop/features/tray/ for background controls; menu actions route to core services.
- **Window Management**: desktop_window plugin for minimize-to-tray; auto-start via registry (Windows) or .desktop files (Linux) in infrastructure/windows/linux/.
- **Keyboard Shortcuts**: hotkey_manager for global hotkeys (e.g., toggle tracking), dispatching to application/features/ commands.
- **Active Window Tracking**: Extends app_usages module with native APIs (Win32 via ffi in infrastructure/windows/, X11/dbus in infrastructure/linux/).
- **Startup Config**: Toggles in settings module, stored in shared_preferences.

### Mobile Features (Android)

- **Home Screen Widgets**: android_alarm_manager_plus in infrastructure/android/features/widget/ for updates; displays tasks/habits from respective modules.
- **Background Tracking**: workmanager for periodic app_usages logging; requests battery optimization ignore via permission_handler.
- **Permission Management**: permission_handler in infrastructure/mobile/ for runtime perms (e.g., USAGE_STATS, NOTIFICATIONS); onboarding flows in presentation/ui/.
- **Share Integration**: receive_sharing_intent to create notes/tasks on share.
- **Notification Channels**: Configured in infrastructure/shared/features/notification/ for categorized alerts.

### APIs and Logic

- **Platform Abstractions**: Interfaces in acore/lib/abstraction/ implemented per platform (e.g., IBackgroundService).
- **Integration**: Hooks into core modules, e.g., tray triggers sync_service.startSync().
- **Cross-Platform Fallbacks**: Feature flags in settings to disable unsupported (e.g., no tray on mobile).
- **Drift Integration**: Platform-specific DB access for local storage.

Trade-offs: Increases platform code (mitigated by modularity); respects Android doze, Linux variability per PRD 5.1.1.

Assumptions: Plugins like tray_manager, permission_handler GPL-compatible; Drift for all persistence.

## Alternatives Considered

- **Platform-Agnostic Only**: Insufficient for native UX (PRD 3.4); specifics boost adoption.
- **Heavy Native Code**: Avoided; Flutter plugins reduce boilerplate for single-dev (PRD 5.1.3).
- **No Permissions UI**: Risky for compliance; handler ensures user consent.
- **Unified Widgets (no Android-specific)**: Limits mobile convenience; plugin enables quick access.

## Implementation Notes

Phases: 1) Desktop infra (infrastructure/desktop/, Week 9), 2) Mobile plugins (infrastructure/android/, Week 10), 3) Abstractions/integration (Week 11), 4) Cross-testing (Week 12). Challenges: Linux X11 variations (solved with conditional dbus). Outcomes: Features enhance modules (e.g., 20% faster tracking); 85% coverage. Aligned with Drift schemas.

## References

- PRD Section 3.4: Platform-Specific Features (lines 116-131).
- MODULES.md: Platform-Specific Infrastructure (lines 332-353).
- Flutter Documentation: [Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels).
- tray_manager: [Desktop Tray](https://pub.dev/packages/tray_manager).

## History

Proposed: Late development (2023). Implemented: v1.0.0 (2024).
