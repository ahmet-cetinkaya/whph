# Implement Application Usage Monitoring

> RFC: 003
> Status: Implemented

## Summary

This RFC describes the app_usages module for WHPH, tracking application usage on desktop (Windows/Linux) within the modular architecture using core/application/features/app_usages/ for services and queries. It automatically logs time in apps, provides analytics with categorization, ignore rules, and charts via Flutter and Drift, helping users optimize focus patterns.

## Motivation

For remote workers (PRD 2.1, 4.3), automatic tracking and analysis enable productivity insights (PRD 1.3). It fills gaps in manual/cloud-dependent apps, using local-first design with dependencies on platform infrastructure and persistence modules for cross-platform compatibility.

## Detailed Design

Clean architecture: domain in core/domain/features/app_usages/, application layer in core/application/features/app_usages/, persistence via Drift in infrastructure/persistence/features/app_usages/, UI in presentation/ui/features/app_usages/. Core components:

### Data Models

- **UsageSession Entity** (core/domain/features/app_usages/models/usage_session_model.dart): Fields: id (UUID), appName (String), executablePath (String?), category (enum: Productive/Distracting/Neutral), startTime/endTime (DateTime?), duration (Duration), windowTitle (String?), createdAt (DateTime).
- **Category Mapping**: Table for rules: appName to category/ignore.
- **Storage**: Drift (SQLite) with tables/views for sessions/rules; indexes for date/category aggregation.

### UI Components

- **Dashboard View** (presentation/ui/features/app_usages/widgets/dashboard_view.dart): Pie/line charts with fl_chart for category/time patterns.
- **App List**: ListView with totals, badges, edit rules.
- **Settings Screen**: Form for regex rules, categories.
- **Time Charts**: Interactive fl_chart filters by range; CSV export.
- **Real-Time Monitoring**: Status indicator; background toggle.

### APIs and Logic

- **Platform Channels**: Custom MethodChannel in infrastructure/desktop/features/app_usages/: Win32 API (ffi/win32 package) for GetForegroundWindow (Windows), dbus/xdotool for Linux; polls 5s to log sessions.
- **Categorization**: Match against Drift rules on end; default Neutral.
- **Analytics Queries**: app_usages_queries.dart DAO for sums/patterns (distraction ratios).
- **Ignore Rules**: dart:reg_exp matching; skips logging.
- **Cross-Platform Limits**: Disabled on mobile (PRD 5.1.1); desktop lifecycle for background.
- **Integration**: Depends on platform infrastructure for native APIs, persistence for storage; sync module for multi-device.

Trade-offs: Polling lightweight but misses brief switches; event-driven complex cross-platform. Local Drift privacy-focused, no real-time aggregation without sync.

Assumptions: Native libs (win32, dbus) GPL-compatible; fl_chart for visuals. Offline conflicts resolved timestamp-based in sync module.

## Alternatives Considered

- **Native-Only (no channels)**: Breaks consistency; channels unify logic.
- **Third-Party (RescueTime API)**: Avoided for privacy/open-source (PRD 5.1.3).
- **Manual Logging**: Insufficient for automation (PRD 4.3).
- **Mobile Inclusion**: Dismissed per limits (PRD 5.1.1); desktop-focused.

## Implementation Notes

Phases: 1) Channels/logging (Week 6-7), 2) DB/rules (Week 8), 3) UI/analytics (Week 9), 4) Win/Linux testing (Week 10). Challenges: Linux detection (dbus integration). Outcomes: Tracks 50+ apps/day <1% CPU; 85% coverage. Integrated with notifications.

## References

- [PRD 3.1](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/PRD.md#L61-L68), [4.3](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/PRD.md#L156-L164).
- [MODULES.md: App Usages Module](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/MODULES.md#L32-L58).
- Flutter: [Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels).
- fl_chart: [Charts](https://pub.dev/packages/fl_chart).
- Drift: [ORM](https://pub.dev/packages/drift).
