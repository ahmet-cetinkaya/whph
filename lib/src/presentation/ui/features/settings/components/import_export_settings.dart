import 'package:flutter/material.dart';
import 'package:whph/src/core/application/features/settings/commands/export_data_command.dart';
import 'package:whph/src/core/application/features/settings/commands/import_data_command.dart';
import 'package:whph/main.dart';
import 'package:whph/src/core/shared/utils/logger.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/domain/shared/constants/app_info.dart';
import 'package:whph/src/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/src/presentation/ui/shared/utils/error_helper.dart';

class ImportExportSettings extends StatelessWidget {
  const ImportExportSettings({super.key});

  void _showImportExportDialog(BuildContext context) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: const _ImportExportActionsDialog(),
      size: DialogSize.medium,
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
        onTap: () => _showImportExportDialog(context),
      ),
    );
  }
}

class _ImportExportActionsDialog extends StatefulWidget {
  const _ImportExportActionsDialog();

  @override
  State<_ImportExportActionsDialog> createState() => _ImportExportActionsDialogState();
}

class _ImportExportActionsDialogState extends State<_ImportExportActionsDialog> {
  final _translationService = container.resolve<ITranslationService>();
  final _fileService = container.resolve<IFileService>();
  final PageController _pageController = PageController();
  String? _selectedFilePath;
  ExportDataFileOptions? _selectedExportOption;
  bool _isProcessing = false;

  void _navigateToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _translationService.translate(SettingsTranslationKeys.importExportTitle),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildMainPage(context),
            if (_selectedFilePath != null) _buildImportStrategyPage(context),
            if (_selectedExportOption == null) _buildExportOptionsPage(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMainPage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description Section
        Text(
          _translationService.translate(SettingsTranslationKeys.importExportDescription),
          style: AppTheme.bodyMedium,
        ),
        const SizedBox(height: AppTheme.sizeMedium),

        // Actions Section
        Column(
          children: [
            _ImportExportActionTile(
              icon: Icons.download,
              titleKey: SettingsTranslationKeys.importTitle,
              onTap: () => _handleImport(context),
              isDisabled: _isProcessing,
            ),
            const SizedBox(height: AppTheme.sizeSmall),
            _ImportExportActionTile(
              icon: Icons.upload,
              titleKey: SettingsTranslationKeys.exportTitle,
              onTap: () => _navigateToPage(2),
              isDisabled: _isProcessing,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImportStrategyPage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Section
        Text(
          _translationService.translate(SettingsTranslationKeys.importStrategyTitle),
          style: AppTheme.bodyLarge,
        ),
        const SizedBox(height: AppTheme.sizeMedium),

        // Strategy Options Section
        Column(
          children: [
            _ImportStrategyOption(
              icon: Icons.delete_sweep,
              translationKey: SettingsTranslationKeys.importStrategyReplace,
              strategy: ImportStrategy.replace,
              onSelect: () => _handleStrategySelect(ImportStrategy.replace, context),
              isDisabled: _isProcessing,
            ),
            const SizedBox(height: AppTheme.sizeSmall),
            _ImportStrategyOption(
              icon: Icons.merge,
              translationKey: SettingsTranslationKeys.importStrategyMerge,
              strategy: ImportStrategy.merge,
              onSelect: () => _handleStrategySelect(ImportStrategy.merge, context),
              isDisabled: _isProcessing,
            ),
          ],
        ),

        const SizedBox(height: AppTheme.sizeLarge),

        // Navigation Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            TextButton(
              onPressed: _isProcessing
                  ? null
                  : () {
                      setState(() {
                        _selectedFilePath = null;
                      });
                      _navigateToPage(0);
                    },
              child: Text(
                _translationService.translate(SharedTranslationKeys.backButton),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExportOptionsPage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Section
        Text(
          _translationService.translate(SettingsTranslationKeys.exportSelectType),
          style: AppTheme.bodyLarge,
        ),
        const SizedBox(height: AppTheme.sizeMedium),

        // Export Options Section
        Column(
          children: [
            _ExportOptionTile(
              icon: Icons.code,
              title: 'JSON',
              descriptionKey: SettingsTranslationKeys.exportJsonDescription,
              fileOption: ExportDataFileOptions.json,
              onSelect: () => _handleExportOptionSelect(ExportDataFileOptions.json, context),
              isDisabled: _isProcessing,
            ),
            const SizedBox(height: AppTheme.sizeSmall),
            _ExportOptionTile(
              icon: Icons.table_chart,
              title: 'CSV',
              descriptionKey: SettingsTranslationKeys.exportCsvDescription,
              fileOption: ExportDataFileOptions.csv,
              onSelect: () => _handleExportOptionSelect(ExportDataFileOptions.csv, context),
              isDisabled: _isProcessing,
            ),
          ],
        ),

        const SizedBox(height: AppTheme.sizeLarge),

        // Navigation Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => _navigateToPage(0),
              child: Text(
                _translationService.translate(SharedTranslationKeys.backButton),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleImport(BuildContext context) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(SettingsTranslationKeys.importError),
      operation: () async {
        // Pick JSON file
        final filePath = await _fileService.pickFile(
          allowedExtensions: ['json'],
          dialogTitle: _translationService.translate(SettingsTranslationKeys.importSelectFile),
        );

        if (filePath != null && mounted) {
          setState(() {
            _selectedFilePath = filePath;
          });
          _navigateToPage(1);
        }
      },
    );
  }

  Future<void> _handleStrategySelect(ImportStrategy strategy, BuildContext context) async {
    if (_selectedFilePath == null || _isProcessing) return;

    if (context.mounted) {
      setState(() {
        _isProcessing = true;
      });

      OverlayNotificationHelper.showLoading(
          context: context,
          message: _translationService.translate(SettingsTranslationKeys.importInProgress),
          duration: const Duration(minutes: 2));
    }

    await AsyncErrorHandler.execute<ImportDataCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(SettingsTranslationKeys.importError),
      operation: () async {
        // Read file content
        final content = await _fileService.readFile(_selectedFilePath!);
        final mediator = container.resolve<Mediator>();

        // Execute import command
        return await mediator.send<ImportDataCommand, ImportDataCommandResponse>(
          ImportDataCommand(content, strategy),
        );
      },
      onSuccess: (_) {
        if (context.mounted) {
          // Hide loading overlay
          OverlayNotificationHelper.hideNotification();

          // Show success overlay notification
          OverlayNotificationHelper.showSuccess(
            context: context,
            message: _translationService.translate(SettingsTranslationKeys.importSuccess),
            duration: const Duration(seconds: 4),
          );

          // Close dialog
          Navigator.of(context).pop();
        }
      },
      onError: (e) {
        Logger.error("Import failed: $e");

        if (context.mounted) {
          // Hide loading overlay
          OverlayNotificationHelper.hideNotification();

          // Show error overlay notification
          if (e is BusinessException) {
            ErrorHelper.showError(context, e);
          } else {
            ErrorHelper.showUnexpectedError(
              context,
              e,
              StackTrace.current,
              message: _translationService.translate(SettingsTranslationKeys.importError),
            );
          }

          // Reset importing state to allow retry
          setState(() {
            _isProcessing = false;
            _selectedFilePath = null;
          });

          // Navigate back to main page instead of closing modal
          _navigateToPage(0);
        }
      },
    );

    // Reset importing state in case of unexpected completion
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleExportOptionSelect(ExportDataFileOptions option, BuildContext context) async {
    if (_isProcessing || _selectedExportOption == option) return;

    if (context.mounted) {
      setState(() {
        _isProcessing = true;
      });

      OverlayNotificationHelper.showLoading(
        context: context,
        message: _translationService.translate(SettingsTranslationKeys.exportInProgress),
        duration: const Duration(minutes: 2),
      );
    }

    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(SettingsTranslationKeys.exportError),
      operation: () async {
        // Get export data
        final mediator = container.resolve<Mediator>();
        final response = await mediator.send<ExportDataCommand, ExportDataCommandResponse>(
          ExportDataCommand(option),
        );

        // Get save path
        final extension = option == ExportDataFileOptions.json ? 'json' : 'csv';
        final version = AppInfo.version;
        final now = DateTime.now();
        final fileName = 'whph_export_${version}_'
            '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
            '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.$extension';

        String? savePath = await _fileService.getSavePath(
          fileName: fileName,
          allowedExtensions: [extension],
          dialogTitle: _translationService.translate(SettingsTranslationKeys.exportSelectPath),
        );

        // Check if user canceled the save dialog
        if (savePath == null) {
          OverlayNotificationHelper.hideNotification();
          if (context.mounted) {
            OverlayNotificationHelper.showInfo(
              context: context,
              message: _translationService.translate(SettingsTranslationKeys.exportCanceled),
            );
          }
          return;
        }

        // Write file
        await _fileService.writeFile(
          filePath: savePath,
          content: response.fileContent,
        );

        if (context.mounted) {
          // Hide loading overlay and show success overlay notification with file path
          OverlayNotificationHelper.hideNotification();
          OverlayNotificationHelper.showSuccess(
            context: context,
            message: '${_translationService.translate(SettingsTranslationKeys.exportSuccess)}\n📁 $savePath',
            duration: const Duration(seconds: 6),
          );

          // Close dialog on success
          Navigator.of(context).pop();
        }
      },
      onError: (e) {
        Logger.error('Export failed: $e');

        // Show error overlay notification
        if (context.mounted) {
          OverlayNotificationHelper.hideNotification();

          if (e is BusinessException) {
            ErrorHelper.showError(context, e);
          } else {
            ErrorHelper.showUnexpectedError(
              context,
              e,
              StackTrace.current,
              message: _translationService.translate(SettingsTranslationKeys.exportError),
            );
          }
        }
      },
    );
  }
}

class _ImportExportActionTile extends StatelessWidget {
  const _ImportExportActionTile({
    required this.icon,
    required this.titleKey,
    required this.onTap,
    this.isDisabled = false,
  });

  final IconData icon;
  final String titleKey;
  final VoidCallback? onTap;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: isDisabled ? Theme.of(context).disabledColor : null,
        ),
        title: Text(
          translationService.translate(titleKey),
          style: AppTheme.bodyMedium.copyWith(
            color: isDisabled ? Theme.of(context).disabledColor : null,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isDisabled ? Theme.of(context).disabledColor : null,
        ),
        onTap: isDisabled ? null : onTap,
        enabled: !isDisabled,
      ),
    );
  }
}

class _ImportStrategyOption extends StatelessWidget {
  const _ImportStrategyOption({
    required this.icon,
    required this.translationKey,
    required this.strategy,
    required this.onSelect,
    this.isDisabled = false,
  });

  final IconData icon;
  final String translationKey;
  final ImportStrategy strategy;
  final VoidCallback? onSelect;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: isDisabled ? Theme.of(context).disabledColor : null,
        ),
        title: Text(
          translationService.translate(translationKey),
          style: AppTheme.bodyMedium.copyWith(
            color: isDisabled ? Theme.of(context).disabledColor : null,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isDisabled ? Theme.of(context).disabledColor : null,
        ),
        onTap: isDisabled ? null : onSelect,
        enabled: !isDisabled,
      ),
    );
  }
}

class _ExportOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String descriptionKey;
  final ExportDataFileOptions fileOption;
  final VoidCallback onSelect;
  final bool isDisabled;

  const _ExportOptionTile({
    required this.icon,
    required this.title,
    required this.descriptionKey,
    required this.fileOption,
    required this.onSelect,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    return Card(
      child: ListTile(
        leading: Icon(icon, color: isDisabled ? Theme.of(context).disabledColor : null),
        title: Text(title,
            style: AppTheme.bodyMedium.copyWith(
              color: isDisabled ? Theme.of(context).disabledColor : null,
            )),
        subtitle: Text(translationService.translate(descriptionKey),
            style: AppTheme.bodySmall.copyWith(
              color: isDisabled ? Theme.of(context).disabledColor : null,
            )),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isDisabled ? Theme.of(context).disabledColor : null,
        ),
        onTap: !isDisabled ? onSelect : null,
        enabled: !isDisabled,
      ),
    );
  }
}
