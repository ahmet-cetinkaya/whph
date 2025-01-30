import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:whph/application/features/settings/commands/export_data_command.dart';
import 'package:whph/application/features/settings/commands/import_data_command.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/settings/constants/settings_translation_keys.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';

class ImportExportSettings extends StatelessWidget {
  const ImportExportSettings({super.key});

  void _showImportExportBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _ImportExportBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.import_export),
        title: Text(
          translationService.translate(SettingsTranslationKeys.importExportTitle),
          style: AppTheme.bodyMedium,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: AppTheme.fontSizeLarge),
        onTap: () => _showImportExportBottomSheet(context),
      ),
    );
  }
}

class _ImportExportBottomSheet extends StatelessWidget {
  _ImportExportBottomSheet() : _translationService = container.resolve<ITranslationService>();

  final ITranslationService _translationService;

  void _showImportStrategyDialog(BuildContext context, String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_translationService.translate(SettingsTranslationKeys.importStrategyTitle)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: Text(_translationService.translate(SettingsTranslationKeys.importStrategyReplace)),
              onTap: () => _importData(context, filePath, ImportStrategy.replace),
            ),
            ListTile(
              leading: const Icon(Icons.merge),
              title: Text(_translationService.translate(SettingsTranslationKeys.importStrategyMerge)),
              onTap: () => _importData(context, filePath, ImportStrategy.merge),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importData(BuildContext context, String filePath, ImportStrategy strategy) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();

      final mediator = container.resolve<Mediator>();
      final command = ImportDataCommand(content, strategy);
      await mediator.send<ImportDataCommand, ImportDataCommandResponse>(command);

      if (context.mounted) {
        Navigator.of(context).pop(); // Close strategy dialog
        Navigator.of(context).pop(); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_translationService.translate(SettingsTranslationKeys.importSuccess)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      if (context.mounted) {
        if (e is BusinessException) {
          ErrorHelper.showError(context, e);
        } else {
          ErrorHelper.showUnexpectedError(context, e, stackTrace);
        }
      }
    }
  }

  Future<void> _handleImport(BuildContext context) async {
    Navigator.of(context).pop(); // Close bottom sheet before starting import
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      if (context.mounted) {
        _showImportStrategyDialog(context, result.files.single.path!);
      }
    }
  }

  Future<void> _handleExport(BuildContext context) async {
    Navigator.of(context).pop(); // Close bottom sheet before starting export
    showModalBottomSheet(
      context: context,
      builder: (context) => _ExportOptionsBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_translationService.translate(SettingsTranslationKeys.importExportSelectAction)),
          ListTile(
            leading: const Icon(Icons.download),
            title: Text(_translationService.translate(SettingsTranslationKeys.importTitle)),
            onTap: () => _handleImport(context),
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: Text(_translationService.translate(SettingsTranslationKeys.exportTitle)),
            onTap: () => _handleExport(context),
          ),
        ],
      ),
    );
  }
}

class _ExportOptionsBottomSheet extends StatelessWidget {
  _ExportOptionsBottomSheet() : _translationService = container.resolve<ITranslationService>();

  final ITranslationService _translationService;

  String _getFormattedDate() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  Future<String?> _getSavePath(ExportDataFileOptions fileOption) async {
    final version = AppInfo.version;
    return await FilePicker.platform.saveFile(
      dialogTitle: _translationService.translate(SettingsTranslationKeys.exportSelectPath),
      fileName:
          'whph_export_${version}_${_getFormattedDate()}.${fileOption == ExportDataFileOptions.json ? 'json' : 'csv'}',
      allowedExtensions: [fileOption == ExportDataFileOptions.json ? 'json' : 'csv'],
      type: FileType.custom,
    );
  }

  Future<void> _exportData(BuildContext context, ExportDataFileOptions fileOption) async {
    final mediator = container.resolve<Mediator>();
    final command = ExportDataCommand(fileOption);
    final response = await mediator.send<ExportDataCommand, ExportDataCommandResponse>(command);

    try {
      String? savePath = await _getSavePath(fileOption);
      if (savePath == null) return;

      final file = File(savePath);
      await file.writeAsString(response.fileContent);

      if (context.mounted) {
        Navigator.of(context).pop(); // Close export options sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_translationService.translate(SettingsTranslationKeys.exportSuccess)}\n$savePath',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_translationService.translate(SettingsTranslationKeys.exportError)),
            backgroundColor: Colors.red,
          ),
        );
        if (kDebugMode) print("ERROR: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_translationService.translate(SettingsTranslationKeys.exportSelectType)),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('JSON'),
            subtitle: Text(_translationService.translate(SettingsTranslationKeys.exportJsonDescription)),
            onTap: () {
              _exportData(context, ExportDataFileOptions.json);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_chart),
            title: const Text('CSV'),
            subtitle: Text(_translationService.translate(SettingsTranslationKeys.exportCsvDescription)),
            onTap: () {
              _exportData(context, ExportDataFileOptions.csv);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
