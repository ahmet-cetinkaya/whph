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
import 'package:csv/csv.dart';
import 'package:whph/domain/shared/constants/app_info.dart';

enum ExportDataFileOptions { json, csv }

class ExportDataCommand implements IRequest<ExportDataCommandResponse> {
  late ExportDataFileOptions fileOption;

  ExportDataCommand(this.fileOption);
}

class ExportDataCommandResponse {
  final String fileContent;

  ExportDataCommandResponse(this.fileContent);
}

class ExportDataCommandHandler implements IRequestHandler<ExportDataCommand, ExportDataCommandResponse> {
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

  ExportDataCommandHandler({
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
  });

  @override
  Future<ExportDataCommandResponse> call(ExportDataCommand request) async {
    final appUsages = await appUsageRepository.getAll();
    final appUsageTags = await appUsageTagRepository.getAll();
    final appUsageTimeRecords = await appUsageTimeRecordRepository.getAll();
    final appUsageTagRules = await appUsageTagRuleRepository.getAll();
    final habits = await habitRepository.getAll();
    final habitRecords = await habitRecordRepository.getAll();
    final habitTags = await habitTagRepository.getAll();
    final tags = await tagRepository.getAll();
    final tagTags = await tagTagRepository.getAll();
    final tasks = await taskRepository.getAll();
    final taskTags = await taskTagRepository.getAll();
    final taskTimeRecords = await taskTimeRecordRepository.getAll();
    final settings = await settingRepository.getAll();
    final syncDevices = await syncDeviceRepository.getAll();
    final appUsageIgnoreRules = await appUsageIgnoreRuleRepository.getAll();

    final data = {
      'appInfo': {
        'version': AppInfo.version,
      },
      'appUsages': appUsages,
      'appUsageTags': appUsageTags,
      'appUsageTimeRecords': appUsageTimeRecords,
      'appUsageTagRules': appUsageTagRules,
      'habits': habits,
      'habitRecords': habitRecords,
      'habitTags': habitTags,
      'tags': tags,
      'tagTags': tagTags,
      'tasks': tasks,
      'taskTags': taskTags,
      'taskTimeRecords': taskTimeRecords,
      'settings': settings,
      'syncDevices': syncDevices,
      'appUsageIgnoreRules': appUsageIgnoreRules,
    };

    return ExportDataCommandResponse(
      request.fileOption == ExportDataFileOptions.json ? JsonMapper.serialize(data) : _convertToCSV(data),
    );
  }

  String _convertToCSV(Map<String, dynamic> data) {
    final buffer = StringBuffer();

    for (var entry in data.entries) {
      // Add table name as a header
      buffer.writeln('# ${entry.key}');

      if (entry.value is List && entry.value.isNotEmpty) {
        final List<List<dynamic>> rows = [];

        // Add headers
        final firstItem = entry.value.first;
        final Map<String, dynamic> headers = json.decode(JsonMapper.serialize(firstItem));
        rows.add(headers.keys.toList());

        // Add data rows
        for (var item in entry.value) {
          final Map<String, dynamic> row = json.decode(JsonMapper.serialize(item));
          rows.add(row.values.toList());
        }

        // Convert to CSV
        buffer.writeln(const ListToCsvConverter().convert(rows));
        buffer.writeln(); // Empty line between tables
      }
    }

    return buffer.toString();
  }
}
