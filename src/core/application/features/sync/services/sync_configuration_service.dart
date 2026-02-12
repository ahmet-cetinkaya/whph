import 'package:acore/acore.dart' hide IRepository;
import 'package:application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:application/features/habits/services/i_habit_record_repository.dart';
import 'package:application/features/habits/services/i_habit_repository.dart';
import 'package:application/features/habits/services/i_habit_tags_repository.dart';
import 'package:application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:application/shared/services/abstraction/i_repository.dart';
import 'package:domain/features/app_usages/app_usage.dart';
import 'package:domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:domain/features/app_usages/app_usage_tag.dart';
import 'package:domain/features/app_usages/app_usage_time_record.dart';
import 'package:domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:domain/features/habits/habit.dart';
import 'package:domain/features/habits/habit_record.dart';
import 'package:domain/features/habits/habit_tag.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:domain/features/sync/sync_device.dart';
import 'package:domain/features/tags/tag.dart';
import 'package:domain/features/tags/tag_tag.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:domain/features/tasks/task_tag.dart';
import 'package:domain/features/tasks/task_time_record.dart';
import 'package:domain/features/notes/note.dart';
import 'package:domain/features/notes/note_tag.dart';
import 'package:application/features/sync/services/abstraction/i_sync_configuration_service.dart';

/// Implementation of sync configuration service that manages entity configurations
class SyncConfigurationService implements ISyncConfigurationService {
  final Map<String, PaginatedSyncConfig> _configurations = {};

  final IAppUsageRepository _appUsageRepository;
  final IAppUsageTagRepository _appUsageTagRepository;
  final IAppUsageTimeRecordRepository _appUsageTimeRecordRepository;
  final IAppUsageTagRuleRepository _appUsageTagRuleRepository;
  final IAppUsageIgnoreRuleRepository _appUsageIgnoreRuleRepository;
  final IHabitRepository _habitRepository;
  final IHabitRecordRepository _habitRecordRepository;
  final IHabitTagsRepository _habitTagRepository;
  final ITagRepository _tagRepository;
  final ITagTagRepository _tagTagRepository;
  final ITaskRepository _taskRepository;
  final ITaskTagRepository _taskTagRepository;
  final ITaskTimeRecordRepository _taskTimeRecordRepository;
  final ISettingRepository _settingRepository;
  final ISyncDeviceRepository _syncDeviceRepository;
  final IRepository<Note, String> _noteRepository;
  final IRepository<NoteTag, String> _noteTagRepository;

  SyncConfigurationService({
    required IAppUsageRepository appUsageRepository,
    required IAppUsageTagRepository appUsageTagRepository,
    required IAppUsageTimeRecordRepository appUsageTimeRecordRepository,
    required IAppUsageTagRuleRepository appUsageTagRuleRepository,
    required IAppUsageIgnoreRuleRepository appUsageIgnoreRuleRepository,
    required IHabitRepository habitRepository,
    required IHabitRecordRepository habitRecordRepository,
    required IHabitTagsRepository habitTagRepository,
    required ITagRepository tagRepository,
    required ITagTagRepository tagTagRepository,
    required ITaskRepository taskRepository,
    required ITaskTagRepository taskTagRepository,
    required ITaskTimeRecordRepository taskTimeRecordRepository,
    required ISettingRepository settingRepository,
    required ISyncDeviceRepository syncDeviceRepository,
    required IRepository<Note, String> noteRepository,
    required IRepository<NoteTag, String> noteTagRepository,
  })  : _appUsageRepository = appUsageRepository,
        _appUsageTagRepository = appUsageTagRepository,
        _appUsageTimeRecordRepository = appUsageTimeRecordRepository,
        _appUsageTagRuleRepository = appUsageTagRuleRepository,
        _appUsageIgnoreRuleRepository = appUsageIgnoreRuleRepository,
        _habitRepository = habitRepository,
        _habitRecordRepository = habitRecordRepository,
        _habitTagRepository = habitTagRepository,
        _tagRepository = tagRepository,
        _tagTagRepository = tagTagRepository,
        _taskRepository = taskRepository,
        _taskTagRepository = taskTagRepository,
        _taskTimeRecordRepository = taskTimeRecordRepository,
        _settingRepository = settingRepository,
        _syncDeviceRepository = syncDeviceRepository,
        _noteRepository = noteRepository,
        _noteTagRepository = noteTagRepository {
    _initializeConfigurations();
  }

  void _initializeConfigurations() {
    _registerConfiguration(PaginatedSyncConfig<AppUsage>(
      name: 'AppUsage',
      repository: _appUsageRepository,
      getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => _appUsageRepository
          .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
      getPaginatedSyncDataFromDto: (dto) => dto.appUsagesSyncData,
    ));

    _registerConfiguration(PaginatedSyncConfig<AppUsageTag>(
      name: 'AppUsageTag',
      repository: _appUsageTagRepository,
      getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => _appUsageTagRepository
          .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
      getPaginatedSyncDataFromDto: (dto) => dto.appUsageTagsSyncData,
    ));

    _registerConfiguration(PaginatedSyncConfig<AppUsageTimeRecord>(
      name: 'AppUsageTimeRecord',
      repository: _appUsageTimeRecordRepository,
      getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => _appUsageTimeRecordRepository
          .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
      getPaginatedSyncDataFromDto: (dto) => dto.appUsageTimeRecordsSyncData,
    ));

    _registerConfiguration(PaginatedSyncConfig<AppUsageTagRule>(
      name: 'AppUsageTagRule',
      repository: _appUsageTagRuleRepository,
      getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => _appUsageTagRuleRepository
          .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
      getPaginatedSyncDataFromDto: (dto) => dto.appUsageTagRulesSyncData,
    ));

    _registerConfiguration(PaginatedSyncConfig<AppUsageIgnoreRule>(
      name: 'AppUsageIgnoreRule',
      repository: _appUsageIgnoreRuleRepository,
      getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => _appUsageIgnoreRuleRepository
          .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
      getPaginatedSyncDataFromDto: (dto) => dto.appUsageIgnoreRulesSyncData,
    ));

    _registerConfiguration(PaginatedSyncConfig<Habit>(
      name: 'Habit',
      repository: _habitRepository,
      getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => _habitRepository
          .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
      getPaginatedSyncDataFromDto: (dto) => dto.habitsSyncData,
    ));

    _registerConfiguration(PaginatedSyncConfig<HabitRecord>(
      name: 'HabitRecord',
      repository: _habitRecordRepository,
      getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => _habitRecordRepository
          .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
      getPaginatedSyncDataFromDto: (dto) => dto.habitRecordsSyncData,
    ));

    _registerConfiguration(PaginatedSyncConfig<HabitTag>(
      name: 'HabitTag',
      repository: _habitTagRepository,
      getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => _habitTagRepository
          .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
      getPaginatedSyncDataFromDto: (dto) => dto.habitTagsSyncData,
    ));

    _registerConfiguration(PaginatedSyncConfig<Tag>(
      name: 'Tag',
      repository: _tagRepository,
      getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => _tagRepository
          .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
      getPaginatedSyncDataFromDto: (dto) => dto.tagsSyncData,
    ));

    _registerConfiguration(PaginatedSyncConfig<TagTag>(
      name: 'TagTag',
      repository: _tagTagRepository,
      getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => _tagTagRepository
          .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
      getPaginatedSyncDataFromDto: (dto) => dto.tagTagsSyncData,
    ));

    _registerConfiguration(PaginatedSyncConfig<Task>(
      name: 'Task',
      repository: _taskRepository,
      getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => _taskRepository
          .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
      getPaginatedSyncDataFromDto: (dto) => dto.tasksSyncData,
    ));

    _registerConfiguration(PaginatedSyncConfig<TaskTag>(
      name: 'TaskTag',
      repository: _taskTagRepository,
      getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => _taskTagRepository
          .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
      getPaginatedSyncDataFromDto: (dto) => dto.taskTagsSyncData,
    ));

    _registerConfiguration(PaginatedSyncConfig<TaskTimeRecord>(
      name: 'TaskTimeRecord',
      repository: _taskTimeRecordRepository,
      getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => _taskTimeRecordRepository
          .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
      getPaginatedSyncDataFromDto: (dto) => dto.taskTimeRecordsSyncData,
    ));

    _registerConfiguration(PaginatedSyncConfig<Setting>(
      name: 'Setting',
      repository: _settingRepository,
      getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => _settingRepository
          .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
      getPaginatedSyncDataFromDto: (dto) => dto.settingsSyncData,
    ));

    _registerConfiguration(PaginatedSyncConfig<SyncDevice>(
      name: 'SyncDevice',
      repository: _syncDeviceRepository,
      getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => _syncDeviceRepository
          .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
      getPaginatedSyncDataFromDto: (dto) => dto.syncDevicesSyncData,
    ));

    _registerConfiguration(PaginatedSyncConfig<Note>(
      name: 'Note',
      repository: _noteRepository,
      getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => _noteRepository
          .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
      getPaginatedSyncDataFromDto: (dto) => dto.notesSyncData,
    ));

    _registerConfiguration(PaginatedSyncConfig<NoteTag>(
      name: 'NoteTag',
      repository: _noteTagRepository,
      getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => _noteTagRepository
          .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
      getPaginatedSyncDataFromDto: (dto) => dto.noteTagsSyncData,
    ));
  }

  void _registerConfiguration<T extends BaseEntity<String>>(PaginatedSyncConfig<T> config) {
    _configurations[config.name] = config;
  }

  @override
  List<PaginatedSyncConfig> getAllConfigurations() {
    return _configurations.values.toList();
  }

  @override
  PaginatedSyncConfig? getConfiguration(String entityType) {
    return _configurations[entityType];
  }

  @override
  PaginatedSyncConfig<T>? getTypedConfiguration<T extends BaseEntity<String>>(String entityType) {
    final config = _configurations[entityType];
    if (config is PaginatedSyncConfig<T>) {
      return config;
    }
    return null;
  }

  @override
  void registerConfiguration<T extends BaseEntity<String>>(PaginatedSyncConfig<T> config) {
    _configurations[config.name] = config;
  }

  @override
  List<String> getEntityTypeNames() {
    return _configurations.keys.toList();
  }

  @override
  bool hasEntityType(String entityType) {
    return _configurations.containsKey(entityType);
  }
}
