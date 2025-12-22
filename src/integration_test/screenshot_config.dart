/// Screenshot configuration for automated screenshot capture.
///
/// This file defines the screenshots to capture for app store submissions.
library;

/// Configuration for screenshot capture scenarios.
class ScreenshotConfig {
  /// List of screenshot scenarios to capture.
  static const List<ScreenshotScenario> scenarios = [
    // 1. Today Page
    ScreenshotScenario(
      id: 1,
      name: 'today_page',
      description: 'Today page showing daily overview',
      route: '/today',
      waitSeconds: 2,
    ),

    // 2. Task Details Page (Buy Groceries Task)
    ScreenshotScenario(
      id: 2,
      name: 'task_details',
      description: 'Task details for Buy Groceries task',
      route: '/tasks',
      waitSeconds: 2,
      tapText: 'Buy Groceries',
    ),

    // 3. Habit Details Page
    ScreenshotScenario(
      id: 3,
      name: 'habit_details',
      description: 'Habit details page',
      route: '/habits',
      waitSeconds: 2,
      tapText: 'Meditation',
    ),

    // 4. Habit Details Page / Statistics Section
    ScreenshotScenario(
      id: 4,
      name: 'habit_statistics',
      description: 'Habit details statistics section',
      route: '', // Continue from habit details
      waitSeconds: 2,
      scrollToText: 'Statistics',
    ),

    // 5. Note Details Page
    ScreenshotScenario(
      id: 5,
      name: 'note_details',
      description: 'Note details page',
      route: '/notes',
      waitSeconds: 2,
      tapFirst: true,
    ),

    // 6. App Usage View Page
    ScreenshotScenario(
      id: 6,
      name: 'app_usage_view',
      description: 'App usage overview page',
      route: '/app-usages',
      waitSeconds: 3,
    ),

    // 7. App Usage Details Page / Statistics Section
    ScreenshotScenario(
      id: 7,
      name: 'app_usage_statistics',
      description: 'App usage statistics section',
      route: '', // Continue from app-usages
      waitSeconds: 2,
      tapFirst: true,
      scrollToText: 'Statistics',
    ),

    // 8. Tags Page
    ScreenshotScenario(
      id: 8,
      name: 'tags_page',
      description: 'Tags page showing all tags',
      route: '/tags',
      waitSeconds: 2,
    ),
  ];

  /// Maximum retry attempts for each screenshot.
  static const int maxRetries = 3;

  /// Delay between retries in milliseconds.
  static const int retryDelayMs = 1000;
}

/// Represents a single screenshot scenario.
class ScreenshotScenario {
  /// Unique identifier for the scenario (used as filename).
  final int id;

  /// Human-readable name for the scenario.
  final String name;

  /// Description of what this screenshot shows.
  final String description;

  /// Route to navigate to (empty string means continue from previous screen).
  final String route;

  /// Seconds to wait for UI stability before capturing.
  final int waitSeconds;

  /// Text to tap on to navigate to details (optional).
  final String? tapText;

  /// Whether to tap the first item in a list (optional).
  final bool tapFirst;

  /// Text to scroll to before capturing (optional).
  final String? scrollToText;

  /// Whether to scroll down before capturing (optional).
  final bool scrollDown;

  const ScreenshotScenario({
    required this.id,
    required this.name,
    required this.description,
    required this.route,
    required this.waitSeconds,
    this.tapText,
    this.tapFirst = false,
    this.scrollToText,
    this.scrollDown = false,
  });
}
