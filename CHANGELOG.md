# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.20.0] - 2026-01-20

### Added

- **Tag Organization**: Organize tags into three types (labels, contexts, projects) for better categorization
- **Tag Grouping & Sorting**: Group tasks, habits, and notes by tag with customizable tag order
- **Weekly Scheduling**: Set different times for each day when configuring weekly schedules
- **Tag Colors in App Usage**: Display app usage time bars using your tag colors for visual clarity
- **CSV Import**: Import tasks from CSV files with support for priority, dates, and descriptions
- **Android Sharing**: Quickly create tasks and notes directly from Android's share menu
- **Easy Task Completion**: Complete tasks with a simple swipe or directly from notifications
- **Flexible Recurrence**: Set tasks to recur based on completion date (e.g., "3 days after I finish it")
- **Task Reminders**: Get reminded before tasks are due with customizable timing
- **Three-State Habit Tracking**: Track habits as complete, skipped, or missed for more accurate statistics
- **List Grouping**: Group tasks, habits, and notes by date, tag, priority, and more
- **Quick Date Selection**: Choose from presets like "Today", "This Week", "This Month" in date pickers

### Changed

- **Improved Performance**: Lists now load faster and scroll more smoothly on Android
- **Better Date Picker**: More intuitive date and time selection with localized options

### Fixed

- **Linux Integration**: App icon now appears correctly in KDE taskbar on X11
- **Window Detection**: Improved app tracking on Wayland with KDE Plasma
- **Widget Sorting**: Home screen widgets now display items in the correct order
- **Text Input**: Fixed cursor jumping when typing quickly in description fields
- **List Reordering**: Drag-and-drop customization now works reliably in all lists
- **Memory Management**: Fixed memory leaks to improve app stability
- **Import Errors**: Better error messages when CSV imports fail
- **Translation Issues**: Fixed various localization problems across languages
- **Sync Reliability**: Improved sync connection stability and error handling

## [0.19.3] - 2026-01-02

### Added

- Translations for time logging and timer features across all supported languages

### Changed

- Improved Portuguese translation for "Clean Code" (Código Limpo)
- Enhanced book and course translations in demo content
- Refined demo content translations for programming courses in Portuguese

### Fixed

- Removed unused variables from encryption key generation to improve code quality

## [0.19.2] - 2025-12-25

### Fixed

- Promote beta from internal track
- Correct fastlane promotion parameters

## [0.19.1] - 2025-12-24

### Fixed

- Improved alignment of list items for a cleaner appearance
- Refined list item heights for better touch targets on mobile
- Cleaner detail tables with improved responsive layout
- Refined date picker spacing in task details

## [0.19.0] - 2025-12-23

### Added

- **Changelog Dialog**: View version history directly in the app via Settings → About → Changelog
- **Habit View Options**: Choose between grid, list, or calendar views for your habits
- **Task Description Quick Add**: Add descriptions when creating tasks from the quick-add dialog
- **Weekly Recurrence by Days**: Schedule recurring tasks for specific days of the week (e.g., every Monday and Wednesday)
- **App Usage Comparison**: Compare app usage statistics between different time periods
- **Sound Settings**: Customize all app sounds from a unified settings panel
- **Infinity Scroll**: Enable smooth continuous scrolling in lists (available in list options)
- **Linux Theme Auto-Switch**: App automatically switches between light/dark theme based on your Linux desktop settings
- **Notification Position (Mobile)**: Choose where notifications appear on your screen
- **KDE Plasma Integration**: Better integration with KDE Plasma desktop environment
- **Database Reset**: Reset app data with automatic backup before resetting
- **Success Notification**: Receive confirmation when creating tasks
- **Real-Time Log Export**: Stream and export debug logs for troubleshooting

### Changed

- **Modernized Settings Interface**: Cleaner, more responsive settings pages
- **Improved Date Picker**: Better quick-selection options and user experience
- **Larger Detail Pages**: Details pages now use maximum available space
- **Better Task Completion Button**: Larger touch area for easier completion on mobile
- **Enhanced Today View**: Habits section supports dynamic view switching (grid/list/calendar)
- **Card-Based UI**: Calendar and statistics views now use modern card-based layouts
- **Improved Tag Selection**: Enhanced dialog for selecting tags across the app

### Fixed

- Duplicate recurring task instances no longer appear
- Task descriptions are now properly saved
- Task time tracking auto-saves every 10 seconds to prevent data loss
- Time duration units now display correctly (seconds instead of milliseconds)
- Recurring task schedule calculations now preserve date spacing correctly
- App performance and responsiveness improvements
- Various UI rendering issues resolved (card backgrounds, widget layouts)
- Turkish translation case issues corrected
- Czech and German localization improvements for date/time formats
- Database operations optimized for better performance

## [0.18.0] - 2025-10-25

### Added

- Make estimated time truly optional by treating 0 as null
- Add default estimated time setting for tasks with UI and logic
- Implement batch firewall rule addition for Windows and improve detection

### Fixed

- Address Gemini review feedback - remove redundant callbacks and restore UI descriptions
- Add time data service and integrate with habit and tag components
- Rename application layer settings translation keys file and update references
- Replace segmented button for elapsed time dialog
- Address final Gemini review feedback on formatting and readability
- Resolve critical bug and improve error logging consistency
- Address Gemini review feedback on error logging, logic, and usability
- Improve task settings usability and error handling
- Resolve settings logic bug for estimated time persistence
- Address Gemini Code Assist review feedback
- Update lcov info with revised line coverage data
- Improve error handling in PowerShell script execution
- Correct regex pattern and cleanup logic in PowerShell script handling
- Fix netsh command parsing and firewall elevation issues
- Remove obsolete firewall setup initialization
- Improve firewall rule check for non-English systems
- Improve firewall rule detection with PowerShell and fallback
- Improve data migration logic and version handling

## [0.17.1] - 2025-10-13

### Added

- Enhance tour overlay with translation support and improved layout

## [0.17.0] - 2025-10-12

### Added

- Enhance tour navigation with async operations and state persistence
- Add multi-page tour functionality with overlay component
- Add language selection dropdown to onboarding dialog
- Add loading overlay to pages with state management improvements
- Improve user experience for multiple sync errors display
- Implement translation keys with parameters for sync error handling

### Changed

- Initialize onboarding steps once in initState

### Fixed

- Add mounted check before navigation after async gap
- Update help dialog title and content formatting
- Enhance task completion button touch area and recurrence handling
- Improve app initialization timing with context availability check
- Prevent background dim flicker during step transitions
- Wait for page loaded before starting tour
- Wait for page loaded before starting tour
- Wait for page loaded before starting tour
- Wait for page loaded before starting tour
- Wait for page loaded before starting tour
- Prevent data loss in task details date fields during background refresh
- Refactor tag display logic in task_card.dart
- Refactor tag display logic in note_card.dart
- Refactor tag display logic in habit_card.dart
- Refactor tag display logic in app_usage_card.dart
- Remove cursor selection restoration logic from detail components
- Improve tag display in card components with overflow handling
- Capture errorParams in _handleIncomingSync method

## [0.16.5] - 2025-10-02

### Added

- Add duplicate ID validation to data import and migration

### Fixed

- Use modified_date for deduplication to prevent data loss
- Improve migration error handling and add testing constructors
- Improve connection management to prevent pool exhaustion

## [0.16.4] - 2025-10-02

### Added

- Enhance data import with backup, validation, and error handling
- Enhance database migration with validation, backup, and error handling

### Fixed

- Handle missing order column in habit_table migration with explicit column mapping

## [0.16.3] - 2025-10-01

### Added

- Add error handling for app initialization failures

### Fixed

- Remove incorrect multiline buffer assignment
- Handle missing habit_time_record_table in migrations

## [0.16.2] - 2025-10-01

### Fixed

- Enhance task table migration by recreating schema (fixes #96 reported by @ujo4eva)

## [0.16.1] - 2025-09-30

### Fixed

- Add data migrations for habit and task schema updates

## [0.16.0] - 2025-09-30

### Added

- Add toggle for showing subtasks in tag details
- Add completion date range filtering
- Introduce system and user app filtering service
- Distinguish estimated vs manually logged habit time
- Enhance time logging and timer integration for habits/tasks
- Set default estimated time values for habits and tasks
- Implement habit time tracking with timer integration and display
- Add automatic estimated time logging for habits and tasks
- Add manual time logging with total duration display
- Add time logging dialog and total duration query
- Add unified timer component with pomodoro, normal, and stopwatch modes
- Add time tracking support with new repository and schema updates

### Changed

- Add debounce to search filter input
- Optimize queries and fix timer logging behavior
- Optimize duration queries with batch fetching and fix timer logging

### Fixed

- Add task time record repository to registration
- Calculate totalElapsedTime for subtasks
- Correct filtering logic for parent and subtasks inclusion
- Add spacing before times section in today page
- Correct SQL variable binding order in task filtering
- Exclude completed parent tasks when showing subtasks
- Use DATE() for accurate planned date matching in recurrence queries
- Resolve data loss in isolate serialization and enhance conflict resolution
- Enhance serialization robustness and conflict resolution
- Enhance serialization, conflict resolution, and recurrence queries
- Address critical data loss and scalability issues in isolate serialization
- Improve isolate serialization robustness
- Enhance isolate DTO conversion and task recurrence parent ID handling
- Resolve serialization, deduplication, and device pairing issues
- Preserve existing task ID when updating with remote data
- Prevent duplicate recurring tasks in multi-device sync
- Enhance conflict resolution for deletions and recurring tasks
- Prevent input conflicts during data refresh in detail views
- Add primary keys and constraints to habit tables
- Correct elapsed time translation key and update task recurrence locales
- Complete translations and refactor shared keys
- Add primary keys and constraints to habit tables
- Prevent paste conflicts in empty text fields
- Correct date range for calendar habit records query
- Ensure all tagged tasks are included in time totals
- Implement proper time unit handling for habit tracking
- Register add habit time record command handler
- Add time tracking support with new repository and schema updates

## [0.15.0] - 2025-09-14

### Added

- Add comprehensive sync help and manual connection UI translations
- Add security and concurrency controls to desktop sync service
- Enhance Android server sync status monitoring and UI feedback
- Separate paginated sync processing from completion
- Enable bidirectional sync and async server processing
- Handle paginated sync start and completion in desktop services
- Implement paginated sync over persistent websocket connections
- Add targeted device syncing for clients
- Add i18n for connection test messages
- Add i18n support to connection dialogs and refactor server sync service
- Integrate device ID service and validate server config
- Enhance connection UX with manual dialogs and desktop mode switching
- Implement desktop sync with server and client modes
- Start background sync after adding device
- Add translations for manual connection and device addition UI
- Add firewall settings translations
- Implement multi-interface network discovery for device syncing
- Add firewall permission management for desktop platforms
- Automate and enhance firewall rule management for sync
- Add firewall rule management for Linux and Windows
- Introduce habit completion service
- Adjust habit card counter padding and sizing
- Refine icons and data fetching for period-based goals
- Support multiple habit occurrences with progress tracking
- Complete multiple habit occurrences implementation
- Add daily target translations for multiple languages
- Complete Phase 3-4 of multiple habit occurrences implementation
- Implement Phase 2 - application logic for multiple occurrences
- Implement Phase 1 - foundation for multiple daily occurrences
- Add untitled display and auto-focus for new items
- Add platform-specific display for quick add task dialog
- Implement working minimized startup for Hyprland/Wayland
- Add useParentScroll parameter to control list scrolling

### Changed

- Implement client-driven paginated sync and manual connection UI
- Batch fetch records for period-based habits
- Add database index and clean up dead code

### Fixed

- Add scrollability to connect info dialog tabs
- Use tagId instead of id in task tags retrieval
- Implement client-driven paginated sync and reconnection logic
- Use device ID in heartbeat and add connection error i18n
- Enhance desktop client connections with device info and ID injection
- Add debug logging for device discovery failures
- Enhance concurrent connection logic and device ID generation
- Replace hardcoded error messages in add sync device page
- Replace hardcoded error messages with translation keys in manual IP input dialog
- Improve hashCode implementation in network interface service
- Fix late initialization and improve hashCode in device handshake service
- Improve connection validation and cleanup in concurrent connection service
- Add translations for manual connection and error messages
- Add missing program parameter to manual Windows command
- Improve Windows firewall rule detection robustness
- Improve port extraction regex robustness
- Clean up FirewallPermissionCard for production
- Replace hardcoded port 44040 with webSocketPort constant
- Add protocol parameter to checkFirewallRule interface
- Make Windows removeFirewallRule idempotent
- Improve Linux firewall rule checking and removal
- Remove firewall cleanup on application exit
- Remove redundant firewall rule check in Linux
- Quote netsh command arguments for Windows firewall rules
- Resolve build failure with -Werror,-Wunused-result flags
- Improve keyboard handling in responsive bottom sheets
- Correct daily goal completion check and period calculation
- Cast tagIds properly in getListHabits query
- Resolve N+1 query performance issues in habit list and widget services
- Add period-aware filtering for completed habits
- Use daily scores for goal-based streak calculations
- Remove shadows from tag time chart titles
- Improve tag time chart title display and readability
- Display untitled translation for empty tag names
- Remove focusedBorder none from task title input
- Adjust note card title text style for better density
- Resolve tag field flickering and visibility issues in habit details
- Improve quick add dialog stability and keyboard positioning

## [0.14.1] - 2025-09-04

### Changed

- Optimize duplicate cleanup with batch delete operations

### Fixed

- Resolve orphaned task issue caused by duplicate records
- Handle total_duration alias in order by clause
- Update project paths from lib/src to lib structure

## [0.14.0] - 2025-09-04

### Added

- New filter option to easily show or hide subtasks for better task management
- Enhanced debug log export with full language support for smoother troubleshooting
- Improved debug logs now display as overlay notifications for instant feedback
- Complete log export feature with localization for all supported languages
- Added error translations for debug logs in every language to improve user experience
- Introduced advanced settings and comprehensive debug logs functionality for power users
- Add layout toggle for tasks and improve habits layout control
- Add custom sort functionality with drag-and-drop support
- Complete date range filter modernization across all pages
- Add clear button translations and improve date picker UX
- Add DateFilterSetting model with quick selection and auto-refresh support

### Changed

- Optimize order updates with batch processing and simplified command

### Fixed

- Correct localization and recurrence logic issues
- Address PR #47 review feedback
- Add validation message for deadline date in multiple languages
- Improve date validation and recurrence logic
- Improve recurrence and deadline validation with translations
- Resolve task recurrence issues with deadline support
- Dispose TextEditingController to prevent memory leak
- Restore truncated error messages in translations
- Resolve YAML syntax errors and add missing translations
- Logger class logs now visible in debug logs dialog
- Preserve exception stack traces in log export service
- Use platform-safe temporary directory instead of hardcoded /tmp
- Implement working drag-to-top solution with hybrid approach
- Replace temporary drag-to-top fix with persistent solution
- Clean up debug logging and implement temp fix for drag-to-top
- Address final review issues and improve order handling
- Address critical review issues in ordering logic
- Complete missing functionality and remove debug code
- Remove debug code and improve production readiness
- Resolve widget alignment issues in shared components
- Address PR #41 review feedback
- Update to use improved acore DateTimePicker with translations

## [0.13.2] - 2025-08-17

### Added

- **UI Density Settings**: New interface density controls allowing users to adjust text and UI element sizes (Compact, Normal, Large, Larger) for improved readability on high DPI displays
- Complete internationalization support for UI density settings across all supported languages

### Changed

- Optimize task list rendering performance by implementing task card caching
- Improve date calculation performance with intelligent caching and staleness checks
- Optimize display performance for high refresh rate screens
- Enhanced UI density implementation based on code review feedback

### Fixed

- Enable Impeller rendering engine for improved performance
- Validate estimatedTime to prevent negative values in time tracking
- Replace responsive color dialog with standard AlertDialog for better consistency

## [0.13.1] - 2025-08-06

### Added

- Implement single instance application management
- Enhance server-side sync status tracking and UI feedback

### Fixed

- Correct corrupted characters in multiple locale files
- Add AppUsageTimeRecord and HabitRecord entity support to paginated sync
- Use local variables to reduce `MediaQuery` calls
- Avoid `MediaQuery.of()`
- Implement v2/v3 registry-based sync system with bidirectional support
- Replace ResponsiveDialogHelper with standard showDialog
- Remove conditional height logic and comments from detail table

## [0.13.0] - 2025-08-05

### Added

- Add markdown editor tooltips for image, heading, and checkbox
- Remove edit icons and improve spacing in detail forms
- Add support for cs, da, el, fi, nl, no, pt, ro, sl, sv locales

### Fixed

- Improve notification scheduling with better validation and fallback handling
- Implement Windows audio player and add sound assets

## [0.12.0] - 2025-07-31

### Added

- Improve sync help content
- Add custom accent color support

### Fixed

- Use theme service for accent color in ui elements
- Resolve bidirectional sync failure preventing Linux demo data from syncing to Android
- Add background color to appbar in pages

## [0.11.1] - 2025-07-29

### Added

- Implement Digital Wellbeing-compatible usage tracking with precision algorithms
- Add clearer description for dynamic color usage
- Set fallback theme to dark
- Remove initial titles and add placeholders for task, habit, note, and tag inputs

### Fixed

- Prevent UI flicker during permission check and data loading
- Use theme color for onboarding next button text

## [0.11.0] - 2025-07-29

### Added

- Add support for mobile-to-mobile sync
- Add syncing indicator to sync devices page
- Improve qr code scan ui
- Add auto theme mode support
- Integrate dynamic color support
- Add light mode support
- Enhance accuracy with hybrid data approach
- Add work profile detection to device name
- Implement backup and restore functionality with .whph format
- Add widget support for tasks and habits
- Sort languages in menu
- Add Chinese localization support across multiple features
- Add Korean localization support across multiple features
- Add Japanese localization support across various features
- Add Italian localization support across multiple features
- Add Russian localization support across multiple features
- Add Spanish localization support across multiple features
- Add French localization support across multiple features
- Add German localization for notes, settings, sync, tags, tasks, and shared components

### Changed

- Add pagination to synced data and thread isolation

### Fixed

- Hide sync button when server node mode
- Address code review comments from PR #16
- Improve compact habit list view in today page
- Add monochrome icon support
- Delay initial sync by 60 seconds for performance
- Add background to appbar
- Init widget services in only Android
- Add dynamic accent color feature translations
- Improve container initialization and error handling
- Initialize test binding and improve platform handling
- Make device info helper tests platform-agnostic
- Replace magic numbers with named constants Add constants for ratio thresholds and daily usage limits to improve code maintainability and readability. This addresses the code review feedback about using magic numbers in the usage calculation logic.
- Improve work profile detection logic
- Use fully qualified column names in queries
- Address second code review feedback
- Address code review feedback
- Remove unnecessary SizedBox in habits page
- Add event listeners for habit record changes
- Improve tags tooltip logic

## [0.10.1] - 2025-07-17

### Added

- Enhance KDE Wayland window methods
- Add device filtering to app usage features
- Implement application directory service for platforms

### Fixed

- Remove padding from descriptions

## [0.10.0] - 2025-07-16

### Changed

- Internal improvements and maintenance

## [0.9.8] - 2025-07-08

### Added

- Implement accurate foreground app usage tracking for Android

### Changed

- Update logo assets for improved optimization

### Fixed

- Update IconButton visual density
- Add sound feedback on record creation

## [0.9.7] - 2025-07-07

### Changed

- Internal improvements and maintenance

## [0.9.6] - 2025-07-02

### Changed

- Internal improvements and maintenance

## [0.9.5] - 2025-07-02

### Changed

- Internal improvements and maintenance

## [0.9.4] - 2025-07-01

### Fixed

- Improve hourly data collection and processing

## [0.9.3] - 2025-07-01

### Added

- Improve mobile platform sync
- Enhance logging and conflict resolution
- Add check for updates functionality

### Fixed

- Improve list view with separators
- Improve error logging in import/export
- Improve pagination logic in app usage list

## [0.9.2] - 2025-06-30

### Fixed

- Enhance hourly processing of app usage data

## [0.9.1] - 2025-06-27

### Fixed

- Remove unused update check logic for Android

## [0.9.0] - 2025-06-27

### Added

- Improved background tracking of app usage on Android devices for a smoother experience

## [0.8.7] - 2025-06-27

### Added

- Remove APK updating logic and related permissions

## [0.8.6] - 2025-06-27

### Added

- Enhance support dialog logic and settings
- Improve error logging on app startup

### Fixed

- Improve layout structure in settings page

## [0.8.5] - 2025-06-26

### Changed

- Internal improvements and maintenance

## [0.8.4] - 2025-06-25

### Changed

- Internal improvements and maintenance

## [0.8.3] - 2025-06-25

### Changed

- Various behind-the-scenes improvements and optimizations for a better experience

## [0.8.2] - 2025-06-24

### Changed

- Various behind-the-scenes improvements and optimizations for a better experience

## [0.8.1] - 2025-06-24

### Added

- Implement demo data service and configuration
- Standardize padding across UI components
- Aggregate tag items to avoid duplicates
- Simplify note content display logic
- Refresh reminders on language change

### Fixed

- Improve onboarding and support dialog handling
- Remove parent task optional property chip
- Add notifications for habit record changes

## [0.8.0] - 2025-06-21

### Added

- Add sorting options to tag selection
- Disable sorting options based on custom order
- Load initial tags and priority in adding sub task
- Add parent task field in task details

### Fixed

- Ensure parsing handles malformed notifications
- Add tag update listener in task details
- Enhance Android reminder service with translation support

## [0.7.1] - 2025-06-19

### Added

- Add Inno Setup for Windows installer creation

### Fixed

- Remove default window size setting

## [0.7.0] - 2025-06-18

### Added

- Update tag percentage threshold for display
- Add confetti animation for task and habit completion
- Enhance habit streak tracking and UI
- Improve scheduling time handling

### Fixed

- Improve reminder icon layout in HabitCard
- Add tooltip to schedule button
- Handle null values in custom order sorting
- Handle user cancellation during export
- Preserve cursor position during note updates
- Manage tag updates and refresh chart
- Initialize date controllers in didChangeDependencies
- Enhance audio player with looping support
- Add task completion handling in details page
- Adjust elapsed time calculation for accuracy

## [0.6.11] - 2025-06-11

### Fixed

- Update version reference from 0.6.7 to 0.6.10 in tests
- Refactor database migration for app_usage_time_record_table
- Enhance YAML parsing and logging

## [0.6.10] - 2025-06-09

### Added

- Handle boot completed events
- Update default sorting configuration
- Enhance reordering functionality in sort dialog
- Add padding to empty state overlays

### Fixed

- Update date filtering logic
- Update play method to include audio focus
- Update argument keys for navigation payload
- Improve app usage tracking logic on android
- Correct paths for drift database configuration
- Update Windows initialization settings
- Enhance time-only input parsing functionality
- Update date filters to use epoch start
- Update task complete button styling
- Update task time record command
- Ensure safe context usage in date parsing

## [0.6.9] - 2025-06-06

### Added

- Add ignoreArchivedTagVisibility to queries
- Remove unused deadline date calculation

### Fixed

- Adjust padding for layout in layout
- Update date filtering logic in today page
- Add ignore directive for depend_on_referenced_packages

## [0.6.8] - 2025-06-03

### Fixed

- Update tag color handling in app usage and tag details
- Improve tag processing logic in app usage details
- Change padding to center alignment
- Change lock fields dialog size to medium

## [0.6.7] - 2025-06-03

### Added

- Add export and import progress messages

### Fixed

- Update app version in migration tests
- Remove getInitialAppUsages method
- Enhance getById methods to include deleted notes
- Update dialog size to medium for better UX

## [0.6.6] - 2025-06-03

### Added

- Enhance search field with improved styling
- Add padding to task list options
- Update dialog size and behavior for better UX
- Implement data migration service with semantic versioning
- Add wakelock functionality for timer to pomodoro timer
- Update progress bar color logic in pomodoro timer
- Improve UI components for improved layout and consistency
- Implement debounce and save handling improvements

### Fixed

- Add initial app usage collection settings
- Simplify additional widget layout in app usage bar
- Allow custom date for time records

## [0.6.5] - 2025-06-02

### Added

- Enhance TaskCompleteButton with subtask progress
- Standardize dialog sizes across components
- Add ScheduleButton component for task scheduling
- Add isDense option to search filter and components
- Implement data migration service
- Improve layout with Wrap widget
- Wrap TagListOptions in Expanded widget
- Wrap HabitListOptions in Expanded widget
- Enhance saveTimeRecord with custom date

### Fixed

- Update task deletion handling in MarathonPage
- Remove unnecessary padding in responsive layout
- Reduce page size for task list
- Improve layout and alignment in tags page

## [0.6.4] - 2025-06-01

### Added

- Add missing translations and improve structure
- Improve pomodoro timer ui
- Enhance update checking and downloading

### Fixed

- Improve layout and responsiveness across components
- Enhance layout with responsive design
- Reduce default page size from 20 to 10
- Improve layout with SingleChildScrollView
- Simplify time display logic
- Replace GridView with Wrap for layout in app about
- Handle export failures with business exception
- Restructure help content locale in notes

## [0.6.3] - 2025-06-01

### Added

- Update application name and description
- Improve permission handling
- Simplify layout structure in settings page
- Update dialog sizes for improved responsiveness
- Adjust padding and height for better layout
- Enhance task completion handling and selection
- Simplify Marathon page and add dim effect to other UI elements during timeout
- Add label to date dialog and reset confirmation to quick add task dialog

### Fixed

- Ensure tag icon color is set correctly
- Refactor Pomodoro timer notification handling
- Update onboarding dialog permissions descriptions
- Ensure immediate task updates without debounce
- Ensure state updates only when mounted
- Update dialog size ratios for better responsiveness
- Remove fixed dialog size for order dialog
- Improve tag selection dropdown behavior
- Improve mobile height calculations
- Enhance priority select field scrolling and styling
- Improve error handling for overlay notifications
- Simplify external link button label handling
- Improve mobile dialog handling and constraints

## [0.6.2] - 2025-05-30

### Added

- Replace SnackBars with overlay notifications
- Add loading notification with progress indicator

### Fixed

- Use release signing config for build types
- Enhance sync data preparation and logging
- Update query parameter names for consistency

## [0.6.1] - 2025-05-30

### Added

- Add auto-start permission management
- Add auto select task on marathon page
- Add floating action button for task creation
- Add lock settings and clear all functionality
- Improve help menu contents
- Update application name to 'Work Hard Play Hard'
- Refactor BusinessException usage for improved error handling and improve error message on ui
- Add storage permission handling for file operations
- Enhance locale-aware date/time formatting
- Add navigation to tag details in dropdown
- Implement ColorField component for color selection
- Add BorderFadeOverlay component for UI enhancements

### Fixed

- Adjust padding and layout in quick task sheet
- Improve layout and structure of task pages
- Update task scheduling logic and UI
- Implement Pomodoro timer service and integration
- Clean up persistent notifications on app lifecycle events
- Simplify content wrapping in responsive dialog
- Update dialog size and add startup permission
- Improve bottom sheet height handling
- Extend delay for permission checks in settings
- Enhance reminder scheduling and cancellation
- Center reminder icon on habit card
- Adjust task list pagination logic
- Remove totalPageCount from PaginatedList model
- Reduce delay for task completion notification
- Render note content in list
- Enhance filter settings saving mechanism
- Add sorting functionality to task lists in detail pages
- Implement scroll position management in lists
- Constrain dropdown height for better UX
- Improve bottom sheet height calculation for mobile
- Remove unused translation keys for notes and tags
- Streamline loading of saved list option settings

## [0.6.0] - 2025-05-26

### Added

- Enhance tag management and localization
- Update localization for device sync messages
- Enhance settings UI and functionality
- Enhance localization and improve note actions
- Enhance habit management features and UI
- Enhance today page list options and error handling
- Improve delete confirmation and UI elements
- Enhance About section with feedback and contact links
- Add translation key classes for about, calendar, and notes
- Add archivedDate to SaveHabitCommand
- Integrate note and note tag repositories
- Enhance date formatting with locale support
- Migrate setting keys to shared constants
- Implement filter and sort settings persistence for today page
- Enhance functionality with unsaved changes handling in SaveButton
- Implement filter and sort settings persistence for tag lists
- Implement filter and sort settings persistence for app usage lists
- Implement filter and sort settings persistence for note lists
- Implement filter and sort settings persistence for habit lists
- Implement filter and sort settings persistence for task lists
- Add sorting and search functionality in today and marathon pages
- Add sorting and search functionality for tags
- Add sorting options for notes list
- Add sorting and search functionality
- Add sorting functionality for task lists
- Replace help icon with shared constant
- Add tag time bar chart and related filters
- Replace label icons with tag icon
- Add "Other" category to time chart
- Enhance time chart filters with category selection
- Add goal settings to habit details
- Add recurrence tasks
- Add long break and ticking sound options
- Add archive feature for habits
- Add support dialog and update localization for support features
- Implement onboarding dialog with multi-step guidance and permission handling
- Enhance permission handling and app usage filters - Add permission check and handling for app usage features - Update filter state initialization to use current date - Refactor refresh functionality to notify app usage service
- Refactor permission handling UI components
- Add reminders
- Enhance date input selection
- Add app usage statistics to details
- Implement responsive dialog helper for detail pages
- Add bottom navigation for mobile screen and enhance navigation ui
- Replace TagLabel with Label component for improved tag display consistency
- Add note feature
- Add "No Tags" option for tag filtering across various components
- Enhance tag details with related tags and archived state visibility

### Changed

- Enhance component management with event-driven updates and new UI components

### Fixed

- Enhance Windows build process with environment variables
- Enhance Windows build process with workarounds
- Improve Windows build process in CI workflow
- Update Android Gradle plugin and dependencies
- Update flutter_local_notifications plugin version
- Ensure app_usage ProGuard rules are added correctly
- Correct command syntax for fixing Android packages
- Update CardTheme to CardThemeData
- Update default value for reminderDays column in HabitTable to an empty string
- Update isCompleted to use request value
- Handle navigation item clicks correctly
- Improve end date calculations in DateRangeFilter
- Update load more button styling and behavior
- Escape field names in custom order query
- Increase padding for note and tag cards
- Improve add task dialog layout and styling
- Ensure state updates only when mounted during permission checks in exact alarm permission.
- Add delayed permission checks for app usage, battery optimization, exact alarm, and notification permissions
- Add refresh on note creation and update event listeners
- Improve active window tracking and app name extraction
- Improve tag loading and visibility handling in habit details
- Implement AutomaticKeepAliveClientMixin for state preservation across task-related pages
- Add app usage filters component for improved filtering options
- Replace Container with Expanded for better layout management in details pages
- Add respectBottomInset property for bottom inset handling in ResponsiveScaffoldLayout
- Add archived filter functionality and improve tag filtering components

## [0.5.1] - 2025-05-01

### Added

- Simplify task list handling and improve filter functionality in tag details page
- Enhance refresh logic and add tag filter functionality in today page
- Enhance task listing with improved refresh logic and task data model

### Fixed

- Adjust task filtering logic in marathon page
- Ensure context is mounted before popping the navigator in tag select dropdown
- Improve habits list filtering and refresh logic
- Enhance refresh task list on filtering and search functionality
- Improve text field updates and debounce timing in details components
- Display Load More button in reorderable task lists

## [0.5.0] - 2025-04-10

### Added

- Add completed tasks filter toggle and enhance task list rebuilding
- Show tag name on selection in app usage tag rules
- Enhance window detection with multiple strategies and error handling
- Implement dynamic visibility for optional fields in details
- Add task ordering
- Implement fade transition for page navigation
- Add min and max date constraints for date selection
- Add focus management for search input in tag selection dropdown
- Update task completion handling with delayed refresh and clear selection
- Add task creation button to Marathon page with filters
- Display past uncompleted tasks on the Today page
- Enhance task duration formatting with localization support

### Fixed

- Update fix_auto_start_flutter.sh to properly structure build.gradle and AndroidManifest.xml
- Simplify description check and update color opacity methods
- Remove unnecessary controller disposal after scanning
- Handle context mounted check before showing error
- Handle navigation result to refresh list only on changes
- Clear existing task tags before fetching new ones
- Change icon installation to user-specific directory
- Update WebSocket port to 44040 and adjust related connections
- Load and display subtask completion percentage in task details
- Initialize task list state on empty task list

## [0.4.6] - 2025-02-04

### Added

- Enhance QuickTaskBottomSheet with tag selection and clear functionality
- Add completed tasks section with expandable view in task and tag details pages

## [0.4.5] - 2025-02-04

### Fixed

- Improve task deletion callback handling in TaskDetailsPage

## [0.4.4] - 2025-02-03

### Added

- Add option to hide sidebar and handle task deletion callback
- Simplify task section layout in tag details page

### Fixed

- Reorder EisenhowerPriority enum values for sorting
- Add translation for no app usage message
- Correct duration update logic and enhance task details dialog

## [0.4.3] - 2025-02-02

### Fixed

- Improve error handling and logging during device sync process

## [0.4.2] - 2025-02-01

### Fixed

- Update task navigation to use MaterialPageRoute and refresh sub-tasks on return

## [0.4.1] - 2025-02-01

### Fixed

- Improve layout and spacing in AppAbout component

## [0.4.0] - 2025-02-01

### Added

- Add support for sub-tasks and parent task relationships; update localization and database schema

## [0.3.2] - 2025-01-31

### Fixed

- Remove inconsistent icon sizes across various pages

## [0.3.1] - 2025-01-31

### Added

- Add translation keys for tags, sync, settings, and habits; update error handling

### Fixed

- Add file service for android

## [0.3.0] - 2025-01-31

### Added

- Add import/export functionality and update localization
- Implement pagination for fetching tags in various components
- Implement device ID service and update sync device model
- Add tap function to notification setting card
- Add 'Add Habit' tooltip translation in English and Turkish
- Update pattern label translation and add spacing in rule lists
- Add 'no_habits_found' message in Turkish translation
- Move name fields to contents
- Add 'Tags' label in English and Turkish translations; refactor tag details page to use TaskAddButton and improve title handling

## [0.2.1] - 2025-01-29

### Added

- Add tooltips for refresh and help actions in multiple components
- Replace Padding with Center for improved layout in AppAbout component
- Implement localized update dialog

### Fixed

- Adjust spacing for logo in ResponsiveScaffoldLayout based on screen size
- Improve title display in HelpMenu with ellipsis overflow handling

## [0.2.0] - 2025-01-29

### Added

- Configure release signing with keystore and update build.gradle
- Implement APK installation via MethodChannel and update manifest for FileProvider
- Integrate translation service across various components and add localization files
- Integrate translation service for tag components
- Integrate translation service for sync components
- Integrate translation service for settings components
- Integrate translation service for calendar components
- Integrate translation service for calendar components
- Integrate translation service for app usage components and update error messages
- Implement translation service and integrate localization into the app

### Fixed

- Update GitHub Actions workflows to use GITHUB_TOKEN consistently and simplify keystore setup
- Add onUpdated callbacks and to input fields and details components and refresh the components on save
- Update schema to version 10 and implement migration logic for timestamp format

## [0.1.7] - 2025-01-27

### Added

- Add setup and update services
- Integrate app usage ignore rules into sync feature and update related registrations
- Implement add and delete commands for app usage ignore rules
- Add additional fields to save commands

### Fixed

- Enhance Windows update script and remove update checker utility

## [0.1.6] - 2025-01-26

### Added

- Make app bar actions visible on all platforms

## [0.1.5] - 2025-01-26

### Added

- Improve app bar title layout for better responsiveness
- Add help modals for Task Details and Tasks Overview pages
- Add help modals for Tag Details and Tags Overview pages
- Add help modals for QR Code Scanner and Sync Devices pages
- Add help modals for Habit Details and Habits Overview pages
- Add help modal with features and tips for Today view
- Add help modals for App Usage Details and App Usage Rules pages
- Add help modal with Pomodoro Technique guidance and tips
- Add task creation button with planned date support in today page

### Fixed

- Add network security configuration and enhance WebSocket connection handling
- Update color themes and improve text styles in app usage setting components
- Override toString method in BusinessException for better error messaging

## [0.1.4] - 2025-01-26

### Added

- Add scheduling functionality to task cards and lists by default
- Add estimatedTime field to Habit model and related queries

### Fixed

- Display 'Not set' when estimatedTime is null
- Update background colors for work and break states
- Add deviceName to app usage details and name input fields

## [0.1.3] - 2025-01-26

### Added

- Enhance device name retrieval with user information
- Add tag color selection with color picker
- Refactor TagTimeChart to accept customizable height and width
- Clear default description fields for habit and task creation
- Add sound feedback for habit record creation
- Implement Android startup settings service and update dependencies

### Changed

- Remove label enabling from ColorPicker for cleaner UI
- Replace hardcoded values with UI constants for improved maintainability and consistency
- Introduce UI constants for habit messages and icons, and update components to use them
- Enhance UI by adding constants for error messages and labels, and refactor input fields to use them
- Introduce shared UI constants for icons and messages, and refactor task components to utilize them

### Fixed

- Improve task tag display with constrained width and ellipsis overflow
- Optimize layout structure for filters and calendar display
- Update bottom sheet background color to use color scheme surface

## [0.1.2] - 2025-01-25

### Fixed

- Ensure tasks list is marked as non-empty on refresh
- Enhance Linux and Windows services to dynamically locate and execute active window scripts
- Remove 'Release' prefix from workflow release names

## [0.1.1] - 2025-01-24

### Added

- Add release steps for Android, Linux, and Windows workflows
- Implement DeviceInfoHelper for retrieving device names across platforms

### Fixed

- Update release workflows to use dynamic versioning for APK and archives
- Add libayatana-appindicator3-dev installation to CI workflow for indicator support
- Add libnotify-dev installation to CI workflow for notification support

## [0.1.0] - 2025-01-24

### Added

- Enhance Pomodoro timer display style and add displayLarge text style for better visibility
- Add notification settings management and update notification service
- Implement desktop startup settings service and add related constants
- Integrate setting repository for app usage ignore patterns and update related services
- Add AppUsageTimeRecordWithDetails model and update related services for detailed app usage tracking
- Implement background service for app usage tracking and update permissions
- Add deviceName field to AppUsage and related components
- Add spacing between logo and surrounding elements for improved layout
- Enhance system tray service with new methods and improve timer updates
- Implement mobile notification service and refactor notification handling
- Load audio files from asset bundle instead of file system
- Add spacing adjustments between sections for improved layout
- Improve drawer spacing and styling
- Enhance UI components with improved layouts and styling adjustments
- Enhance sync command structure
- Improve WebSocket message handling with enhanced error reporting and type validation
- Fix compilation issues for app_usage and flutter_local_notifications plugins
- Enhance sync feature by adding error handling and updating repository registrations
- Enhance menu item management by adding insert and remove functionality
- Update tray icon handling and integrate system tray service in Pomodoro timer
- Integrate local notifier and implement notification service
- Implement sound caching and initialization for improved performance
- Add system tray support
- Introduce app usage tag rules and update tag handling in filters and components
- Add time tracking features and update related components
- Enhance tag selection UI with clear button functionality
- Add date range filtering to app usage queries and UI components
- Improve general ui
- Improve styles
- Add maratgon page
- Add HabitTagSection and HabitCalendarView components for enhanced habit tracking
- Replace CircularProgressIndicator with empty state messages in various components
- Reduce tracking intervals and enhance app usage saving logic with overwrite option
- Add migration strategy and update build configurations for drift_dev
- Add isArchived field to Tag model and update related components for archiving functionality
- Move tags field to up in details
- Update task creation and completion handling with new UI components and improved state management
- Enhance task creation with initial tag support and improve task list refresh
- Add query for retrieving habit tags and enhance habit retrieval with associated tags
- Enhance task retrieval with associated tags and update task card layout

### Changed

- Clean up debug prints and improve UI color consistency in tag rule components

### Fixed

- Update fix_android script to use correct script for local notifications and improve error handling
- Update support URL and remove unused navigation item action
- Ensure deleted app usages are excluded from duration queries
- Restrict functionality to desktop platforms only
- Optimize layout and styling in calendar and statistics views
- Update default route layout in TaskDetailsPage for better alignment
- Filter out deleted tags in getListByPrimaryTagId query
- Improve key generation for the add button on the open page
- Remove save event listeners for fix cursor problem on save

## [0.0.2] - 2024-11-06

### Added

- Add error handling and reporting
- Add sounds

### Fixed

- Move update checker to TodayPage's initState for better update management
- Retrieve process ID of the active window on Windows
- Enhance QR code button styling with custom eye and data module shapes
- Improve layout and styling in habit card and list components
- Wrap custom where filter query in parentheses
- Adjust layout and styling in habits components
- Add events to notify to changed entities

## [0.0.1] - 2024-11-04

### Added

- Implement update checker functionality
- General improvement
- Improve sync pages
- Improve app usage pages
- Add max width to calendar
- Improve habit pages
- Add task list to tag detail
- Add custom order support to getList method
- Improve tags pages
- Refactor detail table component and update app theme
- Improve task pages
- Improve today page
- Add tag filter to task list
- Add today page
- Add custom where filter parameters to get list method
- Add custom where filter parameters for repository
- Update theme data
- Add synchronization
- Add android support
- Add month view to details
- Add habit pages
- Add pomodoro timer settings
- Add tags
- Add task management screen
- Add app usage tracking for linux

### Fixed

- Add time to task filter by planned end date in today page
- Add scroll controllers to today page
- Fix hasNext logic in PaginatedList
