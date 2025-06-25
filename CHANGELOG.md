# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.8.3] - 2025-06-25

### Changed
- Version release

## [0.8.2] - 2025-06-24

### Changed
- Version release

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

