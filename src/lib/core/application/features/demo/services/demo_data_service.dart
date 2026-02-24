import 'dart:convert';
import 'package:whph/core/application/features/demo/services/abstraction/i_demo_data_service.dart';
import 'package:whph/core/application/features/demo/models/demo_data/demo_data.dart';
import 'package:whph/core/domain/shared/constants/demo_config.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_tag_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/tasks/task_tag.dart';
import 'package:whph/core/domain/features/habits/habit_tag.dart';
import 'package:whph/core/domain/features/notes/note_tag.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Demo data service implementation
///
/// Handles populating the application with demo data for development,
/// testing, and screenshot purposes.
class DemoDataService implements IDemoDataService {
  final ISettingRepository _settingRepository;
  final ITagRepository _tagRepository;
  final ITaskRepository _taskRepository;
  final ITaskTagRepository _taskTagRepository;
  final ITaskTimeRecordRepository _taskTimeRecordRepository;
  final IHabitRepository _habitRepository;
  final IHabitRecordRepository _habitRecordRepository;
  final IHabitTagsRepository _habitTagRepository;
  final INoteRepository _noteRepository;
  final INoteTagRepository _noteTagRepository;
  final IAppUsageRepository _appUsageRepository;
  final IAppUsageTimeRecordRepository _appUsageTimeRecordRepository;
  final IAppUsageTagRepository _appUsageTagRepository;

  DemoDataService({
    required ISettingRepository settingRepository,
    required ITagRepository tagRepository,
    required ITaskRepository taskRepository,
    required ITaskTagRepository taskTagRepository,
    required ITaskTimeRecordRepository taskTimeRecordRepository,
    required IHabitRepository habitRepository,
    required IHabitRecordRepository habitRecordRepository,
    required IHabitTagsRepository habitTagRepository,
    required INoteRepository noteRepository,
    required INoteTagRepository noteTagRepository,
    required IAppUsageRepository appUsageRepository,
    required IAppUsageTimeRecordRepository appUsageTimeRecordRepository,
    required IAppUsageTagRepository appUsageTagRepository,
  })  : _settingRepository = settingRepository,
        _tagRepository = tagRepository,
        _taskRepository = taskRepository,
        _taskTagRepository = taskTagRepository,
        _taskTimeRecordRepository = taskTimeRecordRepository,
        _habitRepository = habitRepository,
        _habitRecordRepository = habitRecordRepository,
        _habitTagRepository = habitTagRepository,
        _noteRepository = noteRepository,
        _noteTagRepository = noteTagRepository,
        _appUsageRepository = appUsageRepository,
        _appUsageTimeRecordRepository = appUsageTimeRecordRepository,
        _appUsageTagRepository = appUsageTagRepository;

  @override
  Future<void> initializeDemoDataIfNeeded() async {
    Logger.info('DemoDataService: Checking if demo data initialization is needed...');

    final isDemoDataAlreadyInitialized = await isDemoDataInitialized();

    if (isDemoDataAlreadyInitialized) {
      Logger.info('DemoDataService: Demo data already initialized');
      return;
    }

    Logger.info('DemoDataService: Initializing demo data...');
    // Clear entire database first to ensure clean state
    await _clearEntireDatabase();
    await populateDemoData();
    await _markDemoDataAsInitialized();
    Logger.info('DemoDataService: Demo data initialization completed');
  }

  @override
  Future<void> resetDemoData() async {
    Logger.info('DemoDataService: Resetting demo data...');
    await _clearEntireDatabase();
    await populateDemoData();
    await _markDemoDataAsInitialized();
    Logger.info('DemoDataService: Demo data reset completed');
  }

  @override
  Future<bool> isDemoDataInitialized() async {
    try {
      final setting = await _settingRepository.getByKey(DemoConfig.demoDataInitializedKey);
      return setting != null && setting.value == 'true';
    } catch (e) {
      Logger.error('DemoDataService: Error checking demo data initialization status: $e');
      return false;
    }
  }

  @override
  Future<void> clearDemoData() async {
    Logger.info('DemoDataService: Clearing demo data...');
    await _clearEntireDatabase();
  }

  /// Clears the entire database (all tables)
  Future<void> _clearEntireDatabase() async {
    Logger.info('DemoDataService: Clearing entire database...');

    try {
      // Clear all tables using truncate for complete cleanup
      await _taskTimeRecordRepository.truncate();
      await _taskTagRepository.truncate();
      await _noteTagRepository.truncate();
      await _habitTagRepository.truncate();
      await _habitRecordRepository.truncate();
      await _appUsageTimeRecordRepository.truncate();
      await _appUsageTagRepository.truncate();

      await _taskRepository.truncate();
      await _noteRepository.truncate();
      await _habitRepository.truncate();
      await _appUsageRepository.truncate();
      await _tagRepository.truncate();
      await _settingRepository.truncate();

      Logger.info('DemoDataService: Entire database cleared successfully');
    } catch (e) {
      Logger.error('DemoDataService: Error clearing entire database: $e');
      rethrow;
    }
  }

  @override
  Future<void> populateDemoData() async {
    Logger.info('DemoDataService: Populating demo data...');

    try {
      // Get locale from dart-define SCREENSHOT_LOCALE (default: en)
      const locale = String.fromEnvironment('SCREENSHOT_LOCALE', defaultValue: 'en');
      Logger.info('DemoDataService: Using locale: $locale');

      // Create demo data for the specified locale
      final demoData = DemoData.forLocale(locale);
      final tags = demoData.tags;
      final habits = demoData.habits;
      final tasks = demoData.tasks;
      final notes = demoData.notes;
      final appUsages = demoData.appUsages;

      // Insert tags first (no dependencies)
      Logger.debug('DemoDataService: Inserting ${tags.length} tags...');
      for (final tag in tags) {
        await _tagRepository.add(tag);
      }

      // Insert habits (no dependencies on other demo data)
      Logger.debug('DemoDataService: Inserting ${habits.length} habits...');
      for (final habit in habits) {
        await _habitRepository.add(habit);
      }

      // Insert tasks (no dependencies on other demo data)
      Logger.debug('DemoDataService: Inserting ${tasks.length} tasks...');
      for (final task in tasks) {
        await _taskRepository.add(task);
      }

      // Insert notes (no dependencies on other demo data)
      Logger.debug('DemoDataService: Inserting ${notes.length} notes...');
      for (final note in notes) {
        await _noteRepository.add(note);
      }

      // Insert app usages (no dependencies on other demo data)
      Logger.debug('DemoDataService: Inserting ${appUsages.length} app usages...');
      for (final appUsage in appUsages) {
        await _appUsageRepository.add(appUsage);
      }

      // Create tag associations
      await _createTagAssociations(tags, habits, tasks, notes, appUsages);

      // Insert habit records
      final habitRecords = demoData.generateHabitRecords(habits);
      Logger.debug('DemoDataService: Inserting ${habitRecords.length} habit records...');
      for (final record in habitRecords) {
        await _habitRecordRepository.add(record);
      }

      // Insert task time records
      final taskTimeRecords = demoData.generateTaskTimeRecords(tasks);
      Logger.debug('DemoDataService: Inserting ${taskTimeRecords.length} task time records...');
      for (final record in taskTimeRecords) {
        await _taskTimeRecordRepository.add(record);
      }

      // Insert app usage time records
      final appUsageTimeRecords = demoData.generateAppUsageTimeRecords(appUsages);
      Logger.debug('DemoDataService: Inserting ${appUsageTimeRecords.length} app usage time records...');
      for (final record in appUsageTimeRecords) {
        await _appUsageTimeRecordRepository.add(record);
      }

      // Insert demo filter settings for app usages (last week filter)
      await _populateDemoFilterSettings();

      Logger.info('DemoDataService: Demo data populated successfully');
    } catch (e) {
      Logger.error('DemoDataService: Error populating demo data: $e');
      rethrow;
    }
  }

  /// Creates tag associations for demo entities using index-based assignments
  /// This ensures proper tag associations regardless of locale since array order is consistent
  Future<void> _createTagAssociations(
    List<dynamic> tags,
    List<dynamic> habits,
    List<dynamic> tasks,
    List<dynamic> notes,
    List<dynamic> appUsages,
  ) async {
    Logger.debug('DemoDataService: Creating tag associations...');

    if (tags.isEmpty) return;

    // Tags are created in a fixed order in DemoTags:
    // [0] Work (Label), [1] Personal (Label), [2] Health (Label), [3] Learning (Label),
    // [4] Finance (Label), [5] Entertainment (Label), [6] Social (Label),
    // [7] Home (Context), [8] Office (Context),
    // [9] WHPH App Development (Project), [10] Handmade Furniture (Project),
    // [11] Market (Context)
    final workTag = tags[0];
    final personalTag = tags[1];
    final healthTag = tags[2];
    final learningTag = tags[3];
    // final financeTag = tags[4]; // Not used currently
    final entertainmentTag = tags[5];
    final socialTag = tags[6];
    final homeTag = tags[7];
    final officeTag = tags[8];
    final whphProjectTag = tags[9];
    final furnitureProjectTag = tags[10];
    final marketTag = tags[11];

    // Associate tasks with tags logically
    if (tasks.isNotEmpty) {
      for (int i = 0; i < tasks.length; i++) {
        final task = tasks[i];
        final List<dynamic> targetTags = [];

        // Logical mapping based on task indices in DemoTasks:
        // 0: Complete Project Proposal
        // 1: Review Team Performance
        // 2: Update Resume
        // 3: Buy Groceries
        // 4-8: Grocery Subtasks
        // 9: Learn Microservices
        // 10: Call Mom
        // 11: Review Code
        // 12: Backup Files
        // 13: Learn Flutter
        // 14: Study Patterns
        // 15: Learn API
        // 16: Health Checkup
        // 17: Review Emails

        if ([0, 1, 11, 17].contains(i)) {
          // Work Tasks
          targetTags.addAll([workTag, officeTag, whphProjectTag]);
        } else if ([3, 4, 5, 6, 7, 8].contains(i)) {
          // Grocery Tasks
          targetTags.addAll([personalTag, marketTag]);
        } else if ([10, 16].contains(i)) {
          // Other Personal Tasks (Family, Health)
          targetTags.addAll([personalTag, homeTag]);
          if (i == 10) {
            // Call Mom is a social context too
            targetTags.add(socialTag);
          }
        } else if ([9, 13, 14, 15].contains(i)) {
          // Learning Tasks
          targetTags.addAll([learningTag, homeTag]);
          // Learning Flutter is part of WHPH development project
          if (i == 13) targetTags.add(whphProjectTag);
        } else if ([2, 12].contains(i)) {
          // Mixed Work/Personal
          targetTags.addAll([workTag, personalTag, homeTag]);
        }

        // Apply tags
        for (final tag in targetTags) {
          await _taskTagRepository.add(TaskTag(
            id: KeyHelper.generateStringId(),
            taskId: task.id,
            tagId: tag.id,
            createdDate: DateTime.now(),
          ));
        }
      }
    }

    // Associate habits with tags using index-based assignment
    // Habits are created in a fixed order in DemoHabits
    if (habits.isNotEmpty) {
      // Habit indices (from DemoHabits generator):
      // [0] Meditation - Health
      // [1] Read - Learning
      // [2] Exercise - Health
      // [3] Drink Water - Health
      // [4] Vitamins - Health
      // [5] Journal - Personal
      final habitTagAssignments = [
        healthTag, // [0] Meditation
        learningTag, // [1] Read
        healthTag, // [2] Exercise
        healthTag, // [3] Drink Water
        healthTag, // [4] Vitamins
        personalTag, // [5] Journal
      ];

      for (int i = 0; i < habits.length && i < habitTagAssignments.length; i++) {
        final habit = habits[i];
        final habitTag = habitTagAssignments[i];

        await _habitTagRepository.add(HabitTag(
          id: KeyHelper.generateStringId(),
          habitId: habit.id,
          tagId: habitTag.id,
          createdDate: DateTime.now(),
        ));

        // Habits are mostly at home in demo data
        await _habitTagRepository.add(HabitTag(
          id: KeyHelper.generateStringId(),
          habitId: habit.id,
          tagId: homeTag.id,
          createdDate: DateTime.now(),
        ));
      }
    }

    // Associate notes with tags using index-based assignment
    // Notes are created in a fixed order in DemoNotes
    if (notes.isNotEmpty) {
      // Note indices (from DemoNotes generator):
      // [0] Meeting Notes - Work
      // [1] Shopping List - Personal
      // [2] Book Notes - Learning
      // [3] Travel Ideas - Personal
      // [4] Recipe - Health
      final noteTagAssignments = [
        workTag, // [0] Meeting Notes
        personalTag, // [1] Shopping List
        learningTag, // [2] Book Notes
        personalTag, // [3] Travel Ideas
        healthTag, // [4] Recipe
      ];

      for (int i = 0; i < notes.length && i < noteTagAssignments.length; i++) {
        final note = notes[i];
        final noteTag = noteTagAssignments[i];

        await _noteTagRepository.add(NoteTag(
          id: KeyHelper.generateStringId(),
          noteId: note.id,
          tagId: noteTag.id,
          createdDate: DateTime.now(),
        ));

        // Contexts for notes
        if (noteTag == workTag) {
          await _noteTagRepository.add(NoteTag(
            id: KeyHelper.generateStringId(),
            noteId: note.id,
            tagId: officeTag.id,
            createdDate: DateTime.now(),
          ));
          // Meeting notes belongs to WHPH project
          await _noteTagRepository.add(NoteTag(
            id: KeyHelper.generateStringId(),
            noteId: note.id,
            tagId: whphProjectTag.id,
            createdDate: DateTime.now(),
          ));
        } else {
          await _noteTagRepository.add(NoteTag(
            id: KeyHelper.generateStringId(),
            noteId: note.id,
            tagId: homeTag.id,
            createdDate: DateTime.now(),
          ));
        }
      }
    }

    // Associate app usages with tags using package name matching (not locale-dependent)
    if (appUsages.isNotEmpty) {
      // Work-related app usages (Gmail, Slack, Teams)
      final workAppUsages = appUsages
          .where((appUsage) =>
              appUsage.name == 'com.google.android.gm' ||
              appUsage.name == 'com.slack' ||
              appUsage.name == 'com.microsoft.teams')
          .toList();

      for (final appUsage in workAppUsages) {
        await _appUsageTagRepository.add(AppUsageTag(
          id: KeyHelper.generateStringId(),
          appUsageId: appUsage.id,
          tagId: workTag.id,
          createdDate: DateTime.now(),
        ));
      }

      // Learning app usages (Udemy, Duolingo)
      final learningAppUsages = appUsages
          .where((appUsage) => appUsage.name == 'com.udemy.android' || appUsage.name == 'com.duolingo')
          .toList();

      for (final appUsage in learningAppUsages) {
        await _appUsageTagRepository.add(AppUsageTag(
          id: KeyHelper.generateStringId(),
          appUsageId: appUsage.id,
          tagId: learningTag.id,
          createdDate: DateTime.now(),
        ));
      }

      // Personal app usages (Spotify, Maps, Calendar, Amazon)
      final personalAppUsages = appUsages
          .where((appUsage) =>
              appUsage.name == 'com.spotify.music' ||
              appUsage.name == 'com.google.android.apps.maps' ||
              appUsage.name == 'com.google.android.calendar' ||
              appUsage.name == 'com.amazon.mShop.android.shopping')
          .toList();

      for (final appUsage in personalAppUsages) {
        await _appUsageTagRepository.add(AppUsageTag(
          id: KeyHelper.generateStringId(),
          appUsageId: appUsage.id,
          tagId: personalTag.id,
          createdDate: DateTime.now(),
        ));
      }

      // Entertainment app usages (YouTube, Netflix)
      final entertainmentAppUsages = appUsages
          .where(
              (appUsage) => appUsage.name == 'com.google.android.youtube' || appUsage.name == 'com.netflix.mediaclient')
          .toList();

      for (final appUsage in entertainmentAppUsages) {
        await _appUsageTagRepository.add(AppUsageTag(
          id: KeyHelper.generateStringId(),
          appUsageId: appUsage.id,
          tagId: entertainmentTag.id,
          createdDate: DateTime.now(),
        ));
      }

      // Social app usages (WhatsApp, Instagram, Twitter, Facebook)
      final socialAppUsages = appUsages
          .where((appUsage) =>
              appUsage.name == 'com.whatsapp' ||
              appUsage.name == 'com.instagram.android' ||
              appUsage.name == 'com.twitter.android' ||
              appUsage.name == 'com.facebook.katana')
          .toList();

      for (final appUsage in socialAppUsages) {
        await _appUsageTagRepository.add(AppUsageTag(
          id: KeyHelper.generateStringId(),
          appUsageId: appUsage.id,
          tagId: socialTag.id,
          createdDate: DateTime.now(),
        ));
      }
    }

    Logger.debug('DemoDataService: Tag associations created successfully');
  }

  /// Marks demo data as initialized
  Future<void> _markDemoDataAsInitialized() async {
    Logger.debug('DemoDataService: Marking demo data as initialized...');

    try {
      // Set initialization flag
      final initSetting = Setting(
        id: KeyHelper.generateStringId(),
        key: DemoConfig.demoDataInitializedKey,
        value: 'true',
        valueType: SettingValueType.bool,
        createdDate: DateTime.now(),
      );

      final existingInitSetting = await _settingRepository.getByKey(DemoConfig.demoDataInitializedKey);
      if (existingInitSetting != null) {
        initSetting.id = existingInitSetting.id;
        await _settingRepository.update(initSetting);
      } else {
        await _settingRepository.add(initSetting);
      }

      Logger.debug('DemoDataService: Demo data marked as initialized successfully');
    } catch (e) {
      Logger.error('DemoDataService: Error marking demo data as initialized: $e');
      rethrow;
    }
  }

  /// Populates demo filter settings for app usages with 'last week' date range
  Future<void> _populateDemoFilterSettings() async {
    Logger.debug('DemoDataService: Populating demo filter settings...');

    try {
      final now = DateTime.now();
      final lastWeekStart = now.subtract(const Duration(days: 7));

      // Create app usage filter settings JSON with 'last week' quick selection
      final filterSettingsJson = {
        'showNoTagsFilter': false,
        'showComparison': false,
        'dateFilterSetting': {
          'isQuickSelection': true,
          'quickSelectionKey': 'last_week',
          'startDate': lastWeekStart.toIso8601String(),
          'endDate': now.toIso8601String(),
          'isAutoRefreshEnabled': true,
        },
        'startDate': lastWeekStart.toIso8601String(),
        'endDate': now.toIso8601String(),
      };

      // Store the setting in the database
      final filterSetting = Setting(
        id: KeyHelper.generateStringId(),
        key: 'APP_USAGES_FILTER_SETTINGS',
        value: jsonEncode(filterSettingsJson),
        valueType: SettingValueType.json,
        createdDate: DateTime.now(),
      );

      await _settingRepository.add(filterSetting);
      Logger.debug('DemoDataService: App usage filter settings added successfully');
    } catch (e) {
      Logger.error('DemoDataService: Error populating demo filter settings: $e');
      // Don't rethrow - filter settings are not critical for demo data
    }
  }
}
