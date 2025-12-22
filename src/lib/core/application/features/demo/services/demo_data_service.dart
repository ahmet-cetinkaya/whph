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
      // Create demo data in dependency order
      final tags = DemoData.tags;
      final habits = DemoData.habits;
      final tasks = DemoData.tasks;
      final notes = DemoData.notes;
      final appUsages = DemoData.appUsages;

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
      final habitRecords = DemoData.generateHabitRecords(habits);
      Logger.debug('DemoDataService: Inserting ${habitRecords.length} habit records...');
      for (final record in habitRecords) {
        await _habitRecordRepository.add(record);
      }

      // Insert task time records
      final taskTimeRecords = DemoData.generateTaskTimeRecords(tasks);
      Logger.debug('DemoDataService: Inserting ${taskTimeRecords.length} task time records...');
      for (final record in taskTimeRecords) {
        await _taskTimeRecordRepository.add(record);
      }

      // Insert app usage time records
      final appUsageTimeRecords = DemoData.generateAppUsageTimeRecords(appUsages);
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

  /// Creates tag associations for demo entities
  /// Ensures every task, habit, and note has at least one tag
  Future<void> _createTagAssociations(
    List<dynamic> tags,
    List<dynamic> habits,
    List<dynamic> tasks,
    List<dynamic> notes,
    List<dynamic> appUsages,
  ) async {
    Logger.debug('DemoDataService: Creating tag associations...');

    if (tags.isEmpty) return;

    final workTag = tags.firstWhere((tag) => tag.name == 'Work');
    final personalTag = tags.firstWhere((tag) => tag.name == 'Personal');
    final healthTag = tags.firstWhere((tag) => tag.name == 'Health');
    final learningTag = tags.firstWhere((tag) => tag.name == 'Learning');
    final entertainmentTag = tags.firstWhere((tag) => tag.name == 'Entertainment');
    final socialTag = tags.firstWhere((tag) => tag.name == 'Social');

    // Associate tasks with tags - comprehensive assignment
    if (tasks.isNotEmpty) {
      final assignedTaskIds = <String>{};

      // Work tasks
      final workTasks = tasks
          .where((task) =>
              task.title.contains('Project') ||
              task.title.contains('Team') ||
              task.title.contains('Review') ||
              task.title.contains('Report') ||
              task.title.contains('Status') ||
              task.title.contains('Code') ||
              task.title.contains('Email'))
          .toList();

      for (final task in workTasks) {
        await _taskTagRepository.add(TaskTag(
          id: KeyHelper.generateStringId(),
          taskId: task.id,
          tagId: workTag.id,
          createdDate: DateTime.now(),
        ));
        assignedTaskIds.add(task.id);
      }

      // Personal tasks
      final personalTasks = tasks
          .where((task) =>
              task.title.contains('Groceries') ||
              task.title.contains('Resume') ||
              task.title.contains('Call Mom') ||
              task.title.contains('Backup'))
          .toList();

      for (final task in personalTasks) {
        await _taskTagRepository.add(TaskTag(
          id: KeyHelper.generateStringId(),
          taskId: task.id,
          tagId: personalTag.id,
          createdDate: DateTime.now(),
        ));
        assignedTaskIds.add(task.id);
      }

      // Health tasks
      final healthTasks = tasks.where((task) => task.title.contains('Health')).toList();

      for (final task in healthTasks) {
        await _taskTagRepository.add(TaskTag(
          id: KeyHelper.generateStringId(),
          taskId: task.id,
          tagId: healthTag.id,
          createdDate: DateTime.now(),
        ));
        assignedTaskIds.add(task.id);
      }

      // Learning tasks
      final learningTasks = tasks
          .where((task) =>
              task.title.contains('Learn') ||
              task.title.contains('Study') ||
              task.title.contains('Design') ||
              task.title.contains('API') ||
              task.title.contains('Flutter') ||
              task.title.contains('Dart') ||
              task.title.contains('Course') ||
              task.title.contains('Microservices') ||
              task.title.contains('Architecture'))
          .toList();

      for (final task in learningTasks) {
        await _taskTagRepository.add(TaskTag(
          id: KeyHelper.generateStringId(),
          taskId: task.id,
          tagId: learningTag.id,
          createdDate: DateTime.now(),
        ));
        assignedTaskIds.add(task.id);
      }

      // Assign remaining tasks to Personal tag (fallback)
      final unassignedTasks = tasks.where((task) => !assignedTaskIds.contains(task.id)).toList();
      for (final task in unassignedTasks) {
        await _taskTagRepository.add(TaskTag(
          id: KeyHelper.generateStringId(),
          taskId: task.id,
          tagId: personalTag.id,
          createdDate: DateTime.now(),
        ));
      }
    }

    // Associate habits with tags - comprehensive assignment
    if (habits.isNotEmpty) {
      final assignedHabitIds = <String>{};

      // Health habits
      final healthHabits = habits
          .where((habit) =>
              habit.name.contains('Meditation') ||
              habit.name.contains('Exercise') ||
              habit.name.contains('water') ||
              habit.name.contains('Vitamins'))
          .toList();

      for (final habit in healthHabits) {
        await _habitTagRepository.add(HabitTag(
          id: KeyHelper.generateStringId(),
          habitId: habit.id,
          tagId: healthTag.id,
          createdDate: DateTime.now(),
        ));
        assignedHabitIds.add(habit.id);
      }

      // Learning habits
      final learningHabits = habits.where((habit) => habit.name.contains('Read')).toList();

      for (final habit in learningHabits) {
        await _habitTagRepository.add(HabitTag(
          id: KeyHelper.generateStringId(),
          habitId: habit.id,
          tagId: learningTag.id,
          createdDate: DateTime.now(),
        ));
        assignedHabitIds.add(habit.id);
      }

      // Personal habits
      final personalHabits = habits.where((habit) => habit.name.contains('Journal')).toList();

      for (final habit in personalHabits) {
        await _habitTagRepository.add(HabitTag(
          id: KeyHelper.generateStringId(),
          habitId: habit.id,
          tagId: personalTag.id,
          createdDate: DateTime.now(),
        ));
        assignedHabitIds.add(habit.id);
      }

      // Assign remaining habits to Personal tag (fallback)
      final unassignedHabits = habits.where((habit) => !assignedHabitIds.contains(habit.id)).toList();
      for (final habit in unassignedHabits) {
        await _habitTagRepository.add(HabitTag(
          id: KeyHelper.generateStringId(),
          habitId: habit.id,
          tagId: personalTag.id,
          createdDate: DateTime.now(),
        ));
      }
    }

    // Associate notes with tags - comprehensive assignment
    if (notes.isNotEmpty) {
      final assignedNoteIds = <String>{};

      // Work notes
      final workNotes = notes.where((note) => note.title.contains('Meeting')).toList();

      for (final note in workNotes) {
        await _noteTagRepository.add(NoteTag(
          id: KeyHelper.generateStringId(),
          noteId: note.id,
          tagId: workTag.id,
          createdDate: DateTime.now(),
        ));
        assignedNoteIds.add(note.id);
      }

      // Personal notes
      final personalNotes = notes.where((note) => note.title.contains('Travel')).toList();

      for (final note in personalNotes) {
        await _noteTagRepository.add(NoteTag(
          id: KeyHelper.generateStringId(),
          noteId: note.id,
          tagId: personalTag.id,
          createdDate: DateTime.now(),
        ));
        assignedNoteIds.add(note.id);
      }

      // Health notes
      final healthNotes = notes.where((note) => note.title.contains('Recipe')).toList();

      for (final note in healthNotes) {
        await _noteTagRepository.add(NoteTag(
          id: KeyHelper.generateStringId(),
          noteId: note.id,
          tagId: healthTag.id,
          createdDate: DateTime.now(),
        ));
        assignedNoteIds.add(note.id);
      }

      // Learning notes
      final learningNotes = notes.where((note) => note.title.contains('Book')).toList();

      for (final note in learningNotes) {
        await _noteTagRepository.add(NoteTag(
          id: KeyHelper.generateStringId(),
          noteId: note.id,
          tagId: learningTag.id,
          createdDate: DateTime.now(),
        ));
        assignedNoteIds.add(note.id);
      }

      // Assign remaining notes to Personal tag (fallback)
      final unassignedNotes = notes.where((note) => !assignedNoteIds.contains(note.id)).toList();
      for (final note in unassignedNotes) {
        await _noteTagRepository.add(NoteTag(
          id: KeyHelper.generateStringId(),
          noteId: note.id,
          tagId: personalTag.id,
          createdDate: DateTime.now(),
        ));
      }
    }

    // Associate app usages with tags
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
        value: _jsonEncode(filterSettingsJson),
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

  /// Simple JSON encoder for filter settings
  String _jsonEncode(Map<String, dynamic> json) {
    // Manual JSON encoding to avoid dart:convert import issues
    final buffer = StringBuffer('{');
    var first = true;
    for (final entry in json.entries) {
      if (!first) buffer.write(',');
      first = false;
      buffer.write('"${entry.key}":');
      if (entry.value == null) {
        buffer.write('null');
      } else if (entry.value is bool) {
        buffer.write(entry.value.toString());
      } else if (entry.value is num) {
        buffer.write(entry.value.toString());
      } else if (entry.value is String) {
        buffer.write('"${entry.value}"');
      } else if (entry.value is Map) {
        buffer.write(_jsonEncode(entry.value as Map<String, dynamic>));
      }
    }
    buffer.write('}');
    return buffer.toString();
  }
}
