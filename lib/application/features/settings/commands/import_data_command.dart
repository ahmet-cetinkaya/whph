import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'dart:convert';
import 'package:whph/core/acore/repository/abstraction/i_repository.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/domain/features/tags/tag_tag.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';
import 'package:whph/domain/features/tasks/task_time_record.dart';
import 'package:whph/domain/features/habits/habit.dart';
import 'package:whph/domain/features/habits/habit_record.dart';
import 'package:whph/domain/features/habits/habit_tag.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:whph/domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:whph/domain/features/settings/setting.dart';
import 'package:whph/domain/features/sync/sync_device.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/application/features/settings/constants/setting_translation_keys.dart';

enum ImportStrategy { replace, merge }

class ImportDataCommand implements IRequest<ImportDataCommandResponse> {
  final String fileContent;
  final ImportStrategy strategy;

  ImportDataCommand(this.fileContent, this.strategy);
}

class ImportDataCommandResponse {}

class ImportConfig<T extends BaseEntity> {
  final String name;
  final IRepository repository;
  final T Function(Map<String, dynamic>) fromJson;

  ImportConfig({
    required this.name,
    required this.repository,
    required this.fromJson,
  });
}

class ImportDataCommandHandler implements IRequestHandler<ImportDataCommand, ImportDataCommandResponse> {
  final IAppUsageRepository appUsageRepository;
  final IAppUsageTagRepository appUsageTagRepository;
  final IAppUsageTimeRecordRepository appUsageTimeRecordRepository;
  final IAppUsageTagRuleRepository appUsageTagRuleRepository;
  final IHabitRepository habitRepository;
  final IHabitRecordRepository habitRecordRepository;
  final IHabitTagsRepository habitTagRepository;
  final ITagRepository tagRepository;
  final ITagTagRepository tagTagRepository;
  final ITaskRepository taskRepository;
  final ITaskTagRepository taskTagRepository;
  final ITaskTimeRecordRepository taskTimeRecordRepository;
  final ISettingRepository settingRepository;
  final ISyncDeviceRepository syncDeviceRepository;
  final IAppUsageIgnoreRuleRepository appUsageIgnoreRuleRepository;

  late final List<ImportConfig> _importConfigs;

  ImportDataCommandHandler({
    required this.appUsageRepository,
    required this.appUsageTagRepository,
    required this.appUsageTimeRecordRepository,
    required this.appUsageTagRuleRepository,
    required this.habitRepository,
    required this.habitRecordRepository,
    required this.habitTagRepository,
    required this.tagRepository,
    required this.tagTagRepository,
    required this.taskRepository,
    required this.taskTagRepository,
    required this.taskTimeRecordRepository,
    required this.settingRepository,
    required this.syncDeviceRepository,
    required this.appUsageIgnoreRuleRepository,
  }) {
    _importConfigs = [
      ImportConfig<Tag>(
        name: 'tags',
        repository: tagRepository,
        fromJson: (json) => JsonMapper.deserialize<Tag>(jsonEncode(json))!,
      ),
      ImportConfig<TagTag>(
        name: 'tagTags',
        repository: tagTagRepository,
        fromJson: (json) => JsonMapper.deserialize<TagTag>(jsonEncode(json))!,
      ),
      ImportConfig<AppUsage>(
        name: 'appUsages',
        repository: appUsageRepository,
        fromJson: (json) => JsonMapper.deserialize<AppUsage>(jsonEncode(json))!,
      ),
      ImportConfig<AppUsageTag>(
        name: 'appUsageTags',
        repository: appUsageTagRepository,
        fromJson: (json) => JsonMapper.deserialize<AppUsageTag>(jsonEncode(json))!,
      ),
      ImportConfig<AppUsageTimeRecord>(
        name: 'appUsageTimeRecords',
        repository: appUsageTimeRecordRepository,
        fromJson: (json) => JsonMapper.deserialize<AppUsageTimeRecord>(jsonEncode(json))!,
      ),
      ImportConfig<AppUsageTagRule>(
        name: 'appUsageTagRules',
        repository: appUsageTagRuleRepository,
        fromJson: (json) => JsonMapper.deserialize<AppUsageTagRule>(jsonEncode(json))!,
      ),
      ImportConfig<Habit>(
        name: 'habits',
        repository: habitRepository,
        fromJson: (json) => JsonMapper.deserialize<Habit>(jsonEncode(json))!,
      ),
      ImportConfig<HabitRecord>(
        name: 'habitRecords',
        repository: habitRecordRepository,
        fromJson: (json) => JsonMapper.deserialize<HabitRecord>(jsonEncode(json))!,
      ),
      ImportConfig<HabitTag>(
        name: 'habitTags',
        repository: habitTagRepository,
        fromJson: (json) => JsonMapper.deserialize<HabitTag>(jsonEncode(json))!,
      ),
      ImportConfig<Task>(
        name: 'tasks',
        repository: taskRepository,
        fromJson: (json) => JsonMapper.deserialize<Task>(jsonEncode(json))!,
      ),
      ImportConfig<TaskTag>(
        name: 'taskTags',
        repository: taskTagRepository,
        fromJson: (json) => JsonMapper.deserialize<TaskTag>(jsonEncode(json))!,
      ),
      ImportConfig<TaskTimeRecord>(
        name: 'taskTimeRecords',
        repository: taskTimeRecordRepository,
        fromJson: (json) => JsonMapper.deserialize<TaskTimeRecord>(jsonEncode(json))!,
      ),
      ImportConfig<Setting>(
        name: 'settings',
        repository: settingRepository,
        fromJson: (json) => JsonMapper.deserialize<Setting>(jsonEncode(json))!,
      ),
      ImportConfig<SyncDevice>(
        name: 'syncDevices',
        repository: syncDeviceRepository,
        fromJson: (json) => JsonMapper.deserialize<SyncDevice>(jsonEncode(json))!,
      ),
      ImportConfig<AppUsageIgnoreRule>(
        name: 'appUsageIgnoreRules',
        repository: appUsageIgnoreRuleRepository,
        fromJson: (json) => JsonMapper.deserialize<AppUsageIgnoreRule>(jsonEncode(json))!,
      ),
    ];
  }

  @override
  Future<ImportDataCommandResponse> call(ImportDataCommand request) async {
    final Map<String, dynamic> data = json.decode(request.fileContent);

    // Check version compatibility
    final importedVersion = data['appInfo']?['version'];
    if (importedVersion != AppInfo.version) {
      throw BusinessException(
        SettingTranslationKeys.versionMismatchError,
        args: {
          'importedVersion': importedVersion ?? 'unknown',
          'currentVersion': AppInfo.version,
        },
      );
    }

    if (request.strategy == ImportStrategy.replace) {
      await _clearAllData();
    }

    // Import data sequentially using configs
    for (final config in _importConfigs) {
      if (data[config.name] != null) {
        final items = (data[config.name] as List).cast<Map<String, dynamic>>();
        await _importDataWithConfig(items, config, request.strategy);
      }
    }

    return ImportDataCommandResponse();
  }

  Future<void> _clearAllData() async {
    await Future.wait([
      appUsageRepository.truncate(),
      appUsageTagRepository.truncate(),
      appUsageTimeRecordRepository.truncate(),
      appUsageTagRuleRepository.truncate(),
      habitRepository.truncate(),
      habitRecordRepository.truncate(),
      habitTagRepository.truncate(),
      tagRepository.truncate(),
      tagTagRepository.truncate(),
      taskRepository.truncate(),
      taskTagRepository.truncate(),
      taskTimeRecordRepository.truncate(),
      settingRepository.truncate(),
      syncDeviceRepository.truncate(),
      appUsageIgnoreRuleRepository.truncate(),
    ]);
  }

  Future<void> _importDataWithConfig(
      List<Map<String, dynamic>> items, ImportConfig config, ImportStrategy strategy) async {
    try {
      for (var item in items) {
        // Convert CSV data to correct types
        if (config.name == 'tasks') {
          if (item['priority'] != null) {
            item['priority'] = EisenhowerPriority.values[item['priority'] as int];
          }
          if (item['isCompleted'] is String) {
            item['isCompleted'] = item['isCompleted'].toString().toLowerCase() == 'true';
          }
        }

        final entity = config.fromJson(item);

        if (strategy == ImportStrategy.merge) {
          final existing = await config.repository.getById(entity.id);
          if (existing != null) {
            await config.repository.update(entity);
            continue;
          }
        }

        await config.repository.add(entity);
      }
    } catch (e) {
      throw BusinessException(SettingTranslationKeys.importFailedError);
    }
  }
}
