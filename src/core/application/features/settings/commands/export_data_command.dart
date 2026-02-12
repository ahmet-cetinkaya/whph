import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:mediatr/mediatr.dart';
import 'package:application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
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
import 'package:application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:application/features/notes/services/abstraction/i_note_tag_repository.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:domain/shared/constants/app_info.dart';
import 'package:acore/acore.dart';
import 'package:application/features/settings/constants/settings_translation_keys.dart';
import 'package:application/shared/services/abstraction/i_compression_service.dart';

enum ExportDataFileOptions { json, csv, backup }

class ExportDataCommand implements IRequest<ExportDataCommandResponse> {
  late ExportDataFileOptions fileOption;

  ExportDataCommand(this.fileOption);
}

class ExportDataCommandResponse {
  final dynamic fileContent; // String for JSON/CSV, Uint8List for backup
  final String fileName;
  final String fileExtension;

  ExportDataCommandResponse(this.fileContent, this.fileName, this.fileExtension);
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
  final INoteRepository noteRepository;
  final INoteTagRepository noteTagRepository;
  final ICompressionService compressionService;

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
    required this.noteRepository,
    required this.noteTagRepository,
    required this.compressionService,
  });

  @override
  Future<ExportDataCommandResponse> call(ExportDataCommand request) async {
    try {
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
      final notes = await noteRepository.getAll();
      final noteTags = await noteTagRepository.getAll();

      final data = {
        'appInfo': {
          'version': AppInfo.version,
          'exportDate': DateTime.now().toIso8601String(),
          'format': request.fileOption == ExportDataFileOptions.backup ? 'whph_backup' : 'export',
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
        'notes': notes,
        'noteTags': noteTags,
      };

      // Generate filename and extension based on file option
      final now = DateTime.now();
      final version = AppInfo.version;
      final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

      switch (request.fileOption) {
        case ExportDataFileOptions.json:
          return ExportDataCommandResponse(
            JsonMapper.serialize(data),
            'whph_export_${version}_$timestamp.json',
            'json',
          );
        case ExportDataFileOptions.csv:
          return ExportDataCommandResponse(
            _convertToCSV(data),
            'whph_export_${version}_$timestamp.csv',
            'csv',
          );
        case ExportDataFileOptions.backup:
          final jsonString = JsonMapper.serialize(data);
          final compressedData = await compressionService.createWhphFile(jsonString);
          return ExportDataCommandResponse(
            compressedData,
            'whph_backup_${version}_$timestamp.whph',
            'whph',
          );
      }
    } catch (e) {
      throw BusinessException('Export failed', SettingsTranslationKeys.exportFailedError);
    }
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
