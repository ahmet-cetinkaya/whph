import 'package:flutter/material.dart';
import 'dart:io';
import 'package:whph/application/features/settings/commands/export_data_command.dart';
import 'package:whph/application/features/settings/commands/import_data_command.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/settings/constants/settings_translation_keys.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/core/acore/file/abstraction/i_file_service.dart';
import 'package:path/path.dart' as path;

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
  _ImportExportBottomSheet()
      : _translationService = container.resolve<ITranslationService>(),
        _fileService = container.resolve<IFileService>();

  final ITranslationService _translationService;
  final IFileService _fileService;

  void _showImportStrategyDialog(BuildContext context, String filePath) {
    // Building import strategy dialog

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing dialog by tapping outside
      builder: (dialogContext) => AlertDialog(
        title: Text(_translationService.translate(SettingsTranslationKeys.importStrategyTitle)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildImportStrategyOption(
              dialogContext,
              filePath,
              Icons.delete_sweep,
              SettingsTranslationKeys.importStrategyReplace,
              ImportStrategy.replace,
            ),
            _buildImportStrategyOption(
              dialogContext,
              filePath,
              Icons.merge,
              SettingsTranslationKeys.importStrategyMerge,
              ImportStrategy.merge,
            ),
          ],
        ),
      ),
    );
  }

  ListTile _buildImportStrategyOption(
    BuildContext context,
    String filePath,
    IconData icon,
    String translationKey,
    ImportStrategy strategy,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(_translationService.translate(translationKey)),
      onTap: () {
        Navigator.of(context).pop();
        _importData(context, filePath, strategy);
      },
    );
  }

  Future<void> _importData(BuildContext dialogContext, String filePath, ImportStrategy strategy) async {
    // Get global context for showing success message
    final scaffoldContext = navigatorKey.currentContext;
    if (scaffoldContext == null || !scaffoldContext.mounted) return;

    await AsyncErrorHandler.execute<ImportDataCommandResponse>(
      context: scaffoldContext,
      errorMessage: _translationService.translate(SettingsTranslationKeys.importError),
      operation: () async {
        // Read file content
        final content = await _fileService.readFile(filePath);
        final mediator = container.resolve<Mediator>();

        // Execute import command
        return await mediator.send<ImportDataCommand, ImportDataCommandResponse>(
          ImportDataCommand(content, strategy),
        );
      },
      onSuccess: (_) {
        // Show success message
        _showSuccessMessage(scaffoldContext);
      },
    );
  }

  void _showSuccessMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_translationService.translate(SettingsTranslationKeys.importSuccess)),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _handleImport(BuildContext parentContext) async {
    // Close bottom sheet and wait for animation
    Navigator.of(parentContext).pop();
    await Future.delayed(const Duration(milliseconds: 300));

    if (parentContext.mounted) {
      await AsyncErrorHandler.executeVoid(
        context: parentContext,
        errorMessage: _translationService.translate(SettingsTranslationKeys.importError),
        operation: () async {
          // Pick JSON file
          final filePath = await _fileService.pickFile(
            allowedExtensions: ['json'],
            dialogTitle: _translationService.translate(SettingsTranslationKeys.importSelectFile),
          );

          // Show import strategy dialog if file is selected
          if (filePath != null && navigatorKey.currentContext != null) {
            _showImportStrategyDialog(navigatorKey.currentContext!, filePath);
          }
        },
      );
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_translationService.translate(SettingsTranslationKeys.importExportSelectAction)),
            _buildActionTile(
              icon: Icons.download,
              titleKey: SettingsTranslationKeys.importTitle,
              onTap: () => _handleImport(context),
            ),
            _buildActionTile(
              icon: Icons.upload,
              titleKey: SettingsTranslationKeys.exportTitle,
              onTap: () => _handleExport(context),
            ),
          ],
        ),
      );

  ListTile _buildActionTile({
    required IconData icon,
    required String titleKey,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(_translationService.translate(titleKey)),
      onTap: onTap,
    );
  }
}

class _ExportOptionsBottomSheet extends StatelessWidget {
  _ExportOptionsBottomSheet()
      : _translationService = container.resolve<ITranslationService>(),
        _fileService = container.resolve<IFileService>();

  final ITranslationService _translationService;
  final IFileService _fileService;

  String _getFormattedDate() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  Future<String?> _getSavePath(ExportDataFileOptions fileOption) async {
    final version = AppInfo.version;
    final extension = fileOption == ExportDataFileOptions.json ? 'json' : 'csv';
    final fileName = 'whph_export_${version}_${_getFormattedDate()}.$extension';

    return await _fileService.getSavePath(
      fileName: fileName,
      allowedExtensions: [extension],
      dialogTitle: _translationService.translate(SettingsTranslationKeys.exportSelectPath),
    );
  }

  void _showSuccessMessage(BuildContext context, String displayPath) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_translationService.translate(SettingsTranslationKeys.exportSuccess)}\n$displayPath',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _exportData(BuildContext context, ExportDataFileOptions fileOption) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(SettingsTranslationKeys.exportError),
      operation: () async {
        // Get export data
        final mediator = container.resolve<Mediator>();
        final response = await mediator.send<ExportDataCommand, ExportDataCommandResponse>(
          ExportDataCommand(fileOption),
        );

        // Get save path
        String? savePath = await _getSavePath(fileOption);
        if (savePath == null) {
          if (context.mounted) Navigator.of(context).pop();
          return;
        }

        // Write file
        await _fileService.writeFile(
          filePath: savePath,
          content: response.fileContent,
        );

        if (!context.mounted) return;

        // Close bottom sheet and show success message
        Navigator.of(context).pop();
        final displayPath = Platform.isAndroid ? '/storage/emulated/0/Download/${path.basename(savePath)}' : savePath;
        _showSuccessMessage(context, displayPath);
      },
    );
  }

  ListTile _buildExportOption({
    required IconData icon,
    required String title,
    required String descriptionKey,
    required ExportDataFileOptions fileOption,
    required BuildContext context,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(_translationService.translate(descriptionKey)),
      onTap: () => _exportData(context, fileOption),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_translationService.translate(SettingsTranslationKeys.exportSelectType)),
            _buildExportOption(
              icon: Icons.code,
              title: 'JSON',
              descriptionKey: SettingsTranslationKeys.exportJsonDescription,
              fileOption: ExportDataFileOptions.json,
              context: context,
            ),
            _buildExportOption(
              icon: Icons.table_chart,
              title: 'CSV',
              descriptionKey: SettingsTranslationKeys.exportCsvDescription,
              fileOption: ExportDataFileOptions.csv,
              context: context,
            ),
          ],
        ),
      );
}
