/// Demo data seeder for screenshot automation.
///
/// Populates the app with consistent demo data for screenshot capture,
/// ensuring visually appealing and representative screenshots across all locales.
library;

import 'package:whph/core/domain/shared/constants/demo_config.dart';

/// Service for seeding demo data used in screenshot automation.
///
/// This service creates consistent, visually appealing demo data
/// that showcases the app's features effectively in store screenshots.
class DemoDataSeeder {
  /// Singleton instance.
  static final DemoDataSeeder _instance = DemoDataSeeder._internal();
  factory DemoDataSeeder() => _instance;
  DemoDataSeeder._internal();

  bool _isSeeded = false;

  /// Whether demo data has been seeded in this session.
  bool get isSeeded => _isSeeded;

  /// Seeds demo data if DEMO_MODE is enabled and not already seeded.
  ///
  /// Returns true if seeding was performed, false if skipped.
  Future<bool> seedIfNeeded() async {
    if (!DemoConfig.isDemoModeEnabled) {
      return false;
    }

    if (_isSeeded) {
      return false;
    }

    await _seedDemoData();
    _isSeeded = true;
    return true;
  }

  /// Seeds all demo data.
  Future<void> _seedDemoData() async {
    // Demo data seeding will be implemented based on existing repositories
    // For now, the app's existing demo mode initialization handles this
    // This class serves as the integration point for screenshot automation

    // TODO: Implement specific demo data seeding once we understand
    // the existing DemoConfig initialization flow better
  }

  /// Demo tasks for screenshot scenarios.
  static const List<DemoTask> demoTasks = [
    DemoTask(
      title: 'Complete project proposal',
      priority: 3,
      hasDeadline: true,
      hasTimer: true,
      isCompleted: false,
    ),
    DemoTask(
      title: 'Review team feedback',
      priority: 2,
      hasDeadline: true,
      hasTimer: false,
      isCompleted: false,
    ),
    DemoTask(
      title: 'Prepare presentation slides',
      priority: 3,
      hasDeadline: true,
      hasTimer: true,
      isCompleted: false,
    ),
    DemoTask(
      title: 'Send weekly report',
      priority: 1,
      hasDeadline: false,
      hasTimer: false,
      isCompleted: true,
    ),
    DemoTask(
      title: 'Update documentation',
      priority: 2,
      hasDeadline: false,
      hasTimer: false,
      isCompleted: false,
    ),
  ];

  /// Demo habits for screenshot scenarios.
  static const List<DemoHabit> demoHabits = [
    DemoHabit(
      name: 'Morning exercise',
      streak: 14,
      completedToday: true,
      targetDays: [1, 2, 3, 4, 5],
    ),
    DemoHabit(
      name: 'Read for 30 minutes',
      streak: 7,
      completedToday: false,
      targetDays: [1, 2, 3, 4, 5, 6, 7],
    ),
    DemoHabit(
      name: 'Meditate',
      streak: 21,
      completedToday: true,
      targetDays: [1, 2, 3, 4, 5, 6, 7],
    ),
    DemoHabit(
      name: 'Learn a new skill',
      streak: 5,
      completedToday: false,
      targetDays: [1, 3, 5],
    ),
  ];

  /// Demo notes for screenshot scenarios.
  static const List<DemoNote> demoNotes = [
    DemoNote(
      title: 'Meeting notes',
      preview: 'Discussed Q4 goals and project timelines...',
      hasMarkdown: true,
    ),
    DemoNote(
      title: 'Ideas for new features',
      preview: 'User feedback suggestions and improvements...',
      hasMarkdown: false,
    ),
    DemoNote(
      title: 'Weekly reflection',
      preview: 'Accomplishments and areas for improvement...',
      hasMarkdown: true,
    ),
  ];

  /// Demo tags for screenshot scenarios.
  static const List<DemoTag> demoTags = [
    DemoTag(name: 'Work', color: 0xFF2196F3),
    DemoTag(name: 'Personal', color: 0xFF4CAF50),
    DemoTag(name: 'Health', color: 0xFFE91E63),
    DemoTag(name: 'Learning', color: 0xFF9C27B0),
    DemoTag(name: 'Projects', color: 0xFFFF9800),
  ];
}

/// Demo task data model.
class DemoTask {
  const DemoTask({
    required this.title,
    required this.priority,
    required this.hasDeadline,
    required this.hasTimer,
    required this.isCompleted,
  });

  final String title;
  final int priority;
  final bool hasDeadline;
  final bool hasTimer;
  final bool isCompleted;
}

/// Demo habit data model.
class DemoHabit {
  const DemoHabit({
    required this.name,
    required this.streak,
    required this.completedToday,
    required this.targetDays,
  });

  final String name;
  final int streak;
  final bool completedToday;
  final List<int> targetDays;
}

/// Demo note data model.
class DemoNote {
  const DemoNote({
    required this.title,
    required this.preview,
    required this.hasMarkdown,
  });

  final String title;
  final String preview;
  final bool hasMarkdown;
}

/// Demo tag data model.
class DemoTag {
  const DemoTag({
    required this.name,
    required this.color,
  });

  final String name;
  final int color;
}
