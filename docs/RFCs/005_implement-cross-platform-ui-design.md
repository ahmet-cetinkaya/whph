# Implement Cross-Platform UI Design

> RFC: 005
> Status: Implemented

## Summary

This RFC proposes WHPH's cross-platform UI system, ensuring consistency across Android, Windows, Linux via presentation/ui/features/\*/ for feature UIs and core/shared/utils/ for helpers. It includes responsive layouts, Material Design, themes from settings module, navigation, and visualizations with Flutter, providing intuitive, accessible interfaces adapted through platform infrastructure.

## Motivation

PRD requires consistency (1.3) with adaptive UIs (3.2) for multi-device users (2.3). Addresses fragmentation, emphasizing accessibility/system integration for minimalists, using modular presentation layer dependent on settings for themes and shared for utils.

## Detailed Design

Flutter widgets for rendering, Dart theming; structured in presentation/ui/app/ for global, presentation/ui/features/\*/ for specific. Key aspects:

### Design Principles

- **Responsive Layout**: MediaQuery/LayoutBuilder adapt bottom nav (mobile) to sidebar (desktop); GridView flexible.
- **Material Design**: Material 3 via flutter/material; custom extensions in core/shared/themes/ for branding.
- **Themes**: ThemeMode.system in settings module; dynamic colors via DynamicColor; ThemeData customizations.
- **Accessibility**: Semantics for readers, high-contrast, FocusScope navigation; utils from shared.

### Navigation Components

- **Bottom Navigation (Mobile)**: BottomNavigationBar tabs (Tasks/Habits/Analytics/Notes) in presentation/ui/app/navigation/.
- **Sidebar (Desktop)**: NavigationRail/Drawer persistent; icons/labels.
- **Contextual Menus**: PopupMenuButton for actions; global search SearchDelegate.
- **Routing**: go_router in core/shared/routing/ for declarative, deep linking.

### Data Visualization

- **Charts**: fl_chart for pies/lines/heatmaps in feature UIs (e.g., habits).
- **Calendar Views**: table_calendar synced with calendar module.
- **Dashboard**: Metrics cards responsive (stacked mobile, grid desktop).

### APIs and Logic

- **Theme Provider**: InheritedWidget app-wide; listens system changes via window.onThemeChange in settings_service.dart.
- **Navigation Logic**: Route guards (future auth); shell routes persistent.
- **Visualization Queries**: StreamBuilder real-time from DB; aggregate via feature queries.
- **Platform Adaptations**: MethodChannels in infrastructure/desktop/ for shortcuts; safe areas mobile.
- **Integration**: Depends on settings for theme switching, shared/utils for date/validation, platform infra for native feel.

Trade-offs: Single codebase simplifies but needs tweaks (e.g., Linux GTK via infra); dynamic themes enhance UX with minor complexity.

Assumptions: Material across platforms; libraries go_router, fl_chart, table_calendar GPL-compatible. No custom fonts for lightness; Provider for state (core/shared/state/).

## Alternatives Considered

- **Native UIs**: Overhead for single dev (PRD 5.1.3); Flutter consistent.
- **Custom System**: Avoided; Material battle-tested.
- **Fixed Layouts**: Insufficient varying screens (PRD 3.2.1).
- **Riverpod UI Kit**: Provider sufficient; minimal deps GPL.

## Implementation Notes

Phases: 1) Theme/responsive base (Week 1), 2) Navigation (Week 2), 3) Visuals (Week 3), 4) Accessibility (Week 4). Challenges: Resize persistence (LayoutBuilder). Outcomes: Consistent rendering; 95+ accessibility scores. Integrated all modules.

## References

- [PRD 3.2](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/PRD.md#L75-L95).
- [MODULES.md: Settings](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/MODULES.md#L162-L187), [Shared](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/MODULES.md#L289-L307), [Platform Infra](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/MODULES.md#L331-L353).
- Flutter: [Material](https://docs.flutter.dev/ui/design/material).
- go_router: [Routing](https://pub.dev/packages/go_router).
- fl_chart: [Visualization](https://pub.dev/packages/fl_chart).
