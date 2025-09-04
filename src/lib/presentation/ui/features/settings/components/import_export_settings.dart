import 'package:flutter/material.dart';
import 'package:whph/core/application/features/settings/commands/export_data_command.dart';
import 'package:whph/core/application/features/settings/commands/import_data_command.dart';
import 'package:whph/main.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/utils/error_helper.dart';
import 'dart:typed_data';

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
    final themeService = container.resolve<IThemeService>();

    return StreamBuilder<void>(
      stream: themeService.themeChanges,
      builder: (context, snapshot) {
        final theme = Theme.of(context);

        return Card(
          child: ListTile(
            leading: Icon(
              Icons.import_export,
              color: theme.colorScheme.onSurface,
            ),
            title: Text(
              translationService.translate(SettingsTranslationKeys.importExportTitle),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: AppTheme.fontSizeLarge,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            onTap: () => _showImportExportDialog(context),
          ),
        );
      },
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
  final _themeService = container.resolve<IThemeService>();
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
    return StreamBuilder<void>(
      stream: _themeService.themeChanges,
      builder: (context, snapshot) {
        return Theme(
          data: _themeService.themeData,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Theme.of(context).cardColor,
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
          ),
        );
      },
    );
  }

  Widget _buildMainPage(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description Section
        Text(
          _translationService.translate(SettingsTranslationKeys.importExportDescription),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Section
        Text(
          _translationService.translate(SettingsTranslationKeys.importStrategyTitle),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Section
        Text(
          _translationService.translate(SettingsTranslationKeys.exportSelectType),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppTheme.sizeMedium),

        // Export Options Section
        Column(
          children: [
            _ExportOptionTile(
              icon: Icons.backup,
              titleKey: SettingsTranslationKeys.backupExportTitle,
              descriptionKey: SettingsTranslationKeys.backupExportDescription,
              fileOption: ExportDataFileOptions.backup,
              onSelect: () => _handleExportOptionSelect(ExportDataFileOptions.backup, context),
              isDisabled: _isProcessing,
            ),
            const SizedBox(height: AppTheme.sizeSmall),
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
        // Pick backup file (.whph only) - show all files since .whph is not supported by file picker
        final filePath = await _fileService.pickFile(
          allowedExtensions: null, // Show all files
          dialogTitle: _translationService.translate(SettingsTranslationKeys.importSelectFile),
        );

        if (filePath != null && mounted) {
          // Validate that the selected file is a .whph backup file
          if (!filePath.toLowerCase().endsWith('.whph')) {
            if (context.mounted) {
              OverlayNotificationHelper.showError(
                context: context,
                message: _translationService.translate(SettingsTranslationKeys.backupInvalidFormatError),
                duration: const Duration(seconds: 4),
              );
            }
            return;
          }

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
        // Read backup file as binary data (only .whph files are supported)
        final backupData = await _fileService.readBinaryFile(_selectedFilePath!);
        final mediator = container.resolve<Mediator>();

        // Execute import command for backup file
        return await mediator.send<ImportDataCommand, ImportDataCommandResponse>(
          ImportDataCommand(backupData, strategy),
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

        // Get save path using the filename from response
        String? savePath = await _fileService.getSavePath(
          fileName: response.fileName,
          allowedExtensions: [response.fileExtension],
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

        // Write file based on content type
        if (option == ExportDataFileOptions.backup) {
          if (response.fileContent is! Uint8List) {
            throw Exception('Invalid content type for backup file. Expected Uint8List.');
          }
          // Write binary data for backup files
          await _fileService.writeBinaryFile(
            filePath: savePath,
            data: response.fileContent as Uint8List,
          );
        } else {
          if (response.fileContent is! String) {
            throw Exception('Invalid content type for export file. Expected String.');
          }
          // Write string data for JSON/CSV files
          await _fileService.writeFile(
            filePath: savePath,
            content: response.fileContent as String,
          );
        }

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
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface,
        ),
        title: Text(
          translationService.translate(titleKey),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface,
        ),
        title: Text(
          translationService.translate(translationKey),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        onTap: isDisabled ? null : onSelect,
        enabled: !isDisabled,
      ),
    );
  }
}

class _ExportOptionTile extends StatelessWidget {
  final IconData icon;
  final String? title;
  final String? titleKey;
  final String descriptionKey;
  final ExportDataFileOptions fileOption;
  final VoidCallback onSelect;
  final bool isDisabled;

  const _ExportOptionTile({
    required this.icon,
    this.title,
    this.titleKey,
    required this.descriptionKey,
    required this.fileOption,
    required this.onSelect,
    this.isDisabled = false,
  }) : assert(title != null || titleKey != null, 'Either title or titleKey must be provided');

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    final theme = Theme.of(context);
    final displayTitle = titleKey != null ? translationService.translate(titleKey!) : title!;

    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface,
        ),
        title: Text(
          displayTitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          translationService.translate(descriptionKey),
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        onTap: !isDisabled ? onSelect : null,
        enabled: !isDisabled,
      ),
    );
  }
}
