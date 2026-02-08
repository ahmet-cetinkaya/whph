import 'package:flutter/material.dart';
import 'package:whph/core/application/features/settings/commands/export_data_command.dart';
import 'package:whph/core/application/features/settings/commands/import_data_command.dart';
import 'package:whph/main.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/utils/error_helper.dart';
import 'dart:typed_data';
import 'package:whph/presentation/ui/features/settings/components/settings_menu_tile.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';
import 'package:whph/presentation/ui/shared/components/information_card.dart';
import 'package:whph/core/application/features/tasks/commands/import_tasks_command.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';

class ImportExportSettings extends StatelessWidget {
  const ImportExportSettings({super.key});

  void _showImportExportDialog(BuildContext context) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: const _ImportExportActionsDialog(),
      size: DialogSize.max,
    );
  }

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    final themeService = container.resolve<IThemeService>();

    return StreamBuilder<void>(
      stream: themeService.themeChanges,
      builder: (context, snapshot) {
        return SettingsMenuTile(
          icon: Icons.import_export,
          title: translationService.translate(SettingsTranslationKeys.importExportTitle),
          onTap: () => _showImportExportDialog(context),
          isActive: true,
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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  String? _selectedFilePath;
  String? _selectedTaskFilePath;
  TaskImportType _taskImportType = TaskImportType.generic;
  ExportDataFileOptions? _selectedExportOption;
  bool _isProcessing = false;

  Future<bool> _onWillPop() async {
    if (_navigatorKey.currentState?.canPop() ?? false) {
      _navigatorKey.currentState?.pop();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: _themeService.themeChanges,
      builder: (context, snapshot) {
        return Theme(
          data: _themeService.themeData,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (bool didPop, dynamic result) async {
              if (didPop) return;
              if (await _onWillPop()) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  _translationService.translate(SettingsTranslationKeys.importExportTitle),
                  style: AppTheme.headlineSmall,
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () async {
                    if (await _onWillPop()) {
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  },
                ),
                elevation: 0,
              ),
              body: SafeArea(
                child: Navigator(
                  key: _navigatorKey,
                  onGenerateRoute: (settings) {
                    Widget page;
                    switch (settings.name) {
                      case '/':
                        page = _buildMainPage(context);
                        break;
                      case '/import_source':
                        page = _buildImportSourceSelectionPage(context);
                        break;
                      case '/import_strategy':
                        page = _buildImportStrategyPage(context);
                        break;
                      case '/external_import':
                        page = _buildExternalImportPage(context);
                        break;
                      case '/export':
                        page = _buildExportOptionsPage(context);
                        break;
                      default:
                        page = _buildMainPage(context);
                    }
                    return PageRouteBuilder(
                      settings: settings,
                      pageBuilder: (context, animation, secondaryAnimation) => page,
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        final slideIn = Tween<Offset>(
                          begin: const Offset(1.0, 0.0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));

                        final slideOut = Tween<Offset>(
                          begin: Offset.zero,
                          end: const Offset(-1.0, 0.0),
                        ).animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOut));

                        return SlideTransition(
                          position: slideIn,
                          child: SlideTransition(
                            position: slideOut,
                            child: child,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainPage(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.sizeLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description Section
          InformationCard.themed(
            context: context,
            icon: Icons.info_outline,
            text: _translationService.translate(SettingsTranslationKeys.importExportDescription),
          ),
          const SizedBox(height: AppTheme.sizeLarge),

          // Actions Section
          _ImportExportActionTile(
            icon: Icons.download,
            titleKey: SettingsTranslationKeys.importTitle,
            onTap: () => _handleImport(context),
            isDisabled: _isProcessing,
          ),
          const SizedBox(height: AppTheme.sizeMedium),
          _ImportExportActionTile(
            icon: Icons.upload,
            titleKey: SettingsTranslationKeys.exportTitle,
            onTap: () => _navigatorKey.currentState?.pushNamed('/export'),
            isDisabled: _isProcessing,
          ),
        ],
      ),
    );
  }

  Widget _buildImportSourceSelectionPage(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.sizeLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _translationService.translate(SettingsTranslationKeys.importSourceTitle),
            style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.sizeLarge),
          _ImportOptionTile(
            icon: Icons.settings_backup_restore,
            titleKey: SettingsTranslationKeys.importSourceBackupTitle,
            descriptionKey: SettingsTranslationKeys.importSourceBackupDescription,
            onSelect: () => _handleBackupImport(context),
            isDisabled: _isProcessing,
          ),
          const SizedBox(height: AppTheme.sizeMedium),
          _ImportOptionTile(
            icon: Icons.apps,
            titleKey: SettingsTranslationKeys.importSourceExternalAppsTitle,
            descriptionKey: SettingsTranslationKeys.importSourceExternalAppsDescription,
            onSelect: () => _navigatorKey.currentState?.pushNamed('/external_import'),
            isDisabled: _isProcessing,
          ),
          const SizedBox(height: AppTheme.sizeXLarge),
          TextButton.icon(
            onPressed: () => _navigatorKey.currentState?.pop(),
            icon: const Icon(Icons.arrow_back),
            label: Text(_translationService.translate(SharedTranslationKeys.backButton)),
          ),
        ],
      ),
    );
  }

  Widget _buildExternalImportPage(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.sizeLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _translationService.translate(TaskTranslationKeys.importTasksTitle),
            style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.sizeLarge),
          DropdownButtonFormField<TaskImportType>(
            value: _taskImportType,
            decoration: InputDecoration(
              labelText: _translationService.translate(TaskTranslationKeys.importFormatLabel),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
            ),
            items: [
              DropdownMenuItem(
                value: TaskImportType.generic,
                child: Text(_translationService.translate(TaskTranslationKeys.importFormatsGeneric)),
              ),
              DropdownMenuItem(
                value: TaskImportType.todoist,
                child: Text(_translationService.translate(TaskTranslationKeys.importFormatsTodoist)),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _taskImportType = value);
            },
          ),
          if (_taskImportType == TaskImportType.generic) ...[
            const SizedBox(height: AppTheme.sizeLarge),
            InformationCard.themed(
              context: context,
              icon: Icons.info_outline,
              text: _translationService.translate(TaskTranslationKeys.importGenericInfoDescription),
              isMarkdown: true,
            ),
          ],
          const SizedBox(height: AppTheme.sizeLarge),
          _ImportExportActionTile(
            icon: Icons.file_present,
            titleKey: _selectedTaskFilePath != null
                ? _selectedTaskFilePath!.split('/').last
                : TaskTranslationKeys.importSelectFile,
            onTap: () => _handleTaskFilePick(context),
            isDisabled: _isProcessing,
          ),
          const SizedBox(height: AppTheme.sizeXLarge),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _navigatorKey.currentState?.pop(),
                icon: const Icon(Icons.arrow_back),
                label: Text(_translationService.translate(SharedTranslationKeys.backButton)),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _selectedTaskFilePath != null && !_isProcessing
                    ? () => _handleExternalImportExecute(context)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
                ),
                child: Text(_translationService.translate(TaskTranslationKeys.importButton)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImportStrategyPage(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.sizeLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Text(
            _translationService.translate(SettingsTranslationKeys.importStrategyTitle),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.sizeLarge),

          // Strategy Options Section
          _ImportStrategyOption(
            icon: Icons.delete_sweep,
            translationKey: SettingsTranslationKeys.importStrategyReplace,
            strategy: ImportStrategy.replace,
            onSelect: () => _handleStrategySelect(ImportStrategy.replace, context),
            isDisabled: _isProcessing,
          ),
          const SizedBox(height: AppTheme.sizeMedium),
          _ImportStrategyOption(
            icon: Icons.merge,
            translationKey: SettingsTranslationKeys.importStrategyMerge,
            strategy: ImportStrategy.merge,
            onSelect: () => _handleStrategySelect(ImportStrategy.merge, context),
            isDisabled: _isProcessing,
          ),

          const SizedBox(height: AppTheme.sizeXLarge),

          // Navigation Buttons
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _isProcessing
                  ? null
                  : () {
                      setState(() {
                        _selectedFilePath = null;
                      });
                      _navigatorKey.currentState?.pop();
                    },
              icon: const Icon(Icons.arrow_back),
              label: Text(
                _translationService.translate(SharedTranslationKeys.backButton),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOptionsPage(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.sizeLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Text(
            _translationService.translate(SettingsTranslationKeys.exportSelectType),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.sizeLarge),

          // Export Options Section
          _ExportOptionTile(
            icon: Icons.backup,
            titleKey: SettingsTranslationKeys.backupExportTitle,
            descriptionKey: SettingsTranslationKeys.backupExportDescription,
            fileOption: ExportDataFileOptions.backup,
            onSelect: () => _handleExportOptionSelect(ExportDataFileOptions.backup, context),
            isDisabled: _isProcessing,
          ),
          const SizedBox(height: AppTheme.sizeMedium),
          _ExportOptionTile(
            icon: Icons.code,
            title: 'JSON',
            descriptionKey: SettingsTranslationKeys.exportJsonDescription,
            fileOption: ExportDataFileOptions.json,
            onSelect: () => _handleExportOptionSelect(ExportDataFileOptions.json, context),
            isDisabled: _isProcessing,
          ),
          const SizedBox(height: AppTheme.sizeMedium),
          _ExportOptionTile(
            icon: Icons.table_chart,
            title: 'CSV',
            descriptionKey: SettingsTranslationKeys.exportCsvDescription,
            fileOption: ExportDataFileOptions.csv,
            onSelect: () => _handleExportOptionSelect(ExportDataFileOptions.csv, context),
            isDisabled: _isProcessing,
          ),

          const SizedBox(height: AppTheme.sizeXLarge),

          // Navigation Buttons
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _navigatorKey.currentState?.pop(),
              icon: const Icon(Icons.arrow_back),
              label: Text(
                _translationService.translate(SharedTranslationKeys.backButton),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleImport(BuildContext context) {
    _navigatorKey.currentState?.pushNamed('/import_source');
  }

  Future<void> _handleBackupImport(BuildContext context) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(SettingsTranslationKeys.importError),
      operation: () async {
        final filePath = await _fileService.pickFile(
          allowedExtensions: null,
          dialogTitle: _translationService.translate(SettingsTranslationKeys.importSelectFile),
        );

        if (filePath != null && mounted) {
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
          _navigatorKey.currentState?.pushNamed('/import_strategy');
        }
      },
    );
  }

  Future<void> _handleTaskFilePick(BuildContext context) async {
    try {
      final filePath = await _fileService.pickFile(
        allowedExtensions: ['csv'],
        dialogTitle: _translationService.translate(TaskTranslationKeys.importSelectFile),
      );

      if (filePath != null && mounted) {
        setState(() {
          _selectedTaskFilePath = filePath;
        });
      }
    } on Exception catch (e, stackTrace) {
      Logger.error(
        'Failed to pick CSV file: $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        OverlayNotificationHelper.showError(
          context: context,
          message: '${_translationService.translate(TaskTranslationKeys.importError)}: $e',
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  Future<void> _handleExternalImportExecute(BuildContext context) async {
    if (_selectedTaskFilePath == null || _isProcessing) return;

    setState(() => _isProcessing = true);
    OverlayNotificationHelper.showLoading(
      context: context,
      message: _translationService.translate(SettingsTranslationKeys.importInProgress),
      duration: const Duration(minutes: 2),
    );

    try {
      final response = await AsyncErrorHandler.execute<ImportTasksCommandResponse>(
        context: context,
        errorMessage: _translationService.translate(SettingsTranslationKeys.importError),
        operation: () async {
          final mediator = container.resolve<Mediator>();
          return await mediator.send<ImportTasksCommand, ImportTasksCommandResponse>(
            ImportTasksCommand(
              filePath: _selectedTaskFilePath!,
              importType: _taskImportType,
            ),
          );
        },
      );

      // Success case
      if (context.mounted && response != null) {
        OverlayNotificationHelper.hideNotification();
        final message = response.failureCount == 0
            ? _translationService
                .translate(TaskTranslationKeys.importSuccess, namedArgs: {'count': response.successCount.toString()})
            : _translationService.translate(TaskTranslationKeys.importPartialSuccess,
                namedArgs: {'success': response.successCount.toString(), 'failure': response.failureCount.toString()});

        OverlayNotificationHelper.showSuccess(
          context: context,
          message: message,
          duration: const Duration(seconds: 4),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
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

          // Navigate back to import source selection
          _navigatorKey.currentState?.pop();
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

        // Prepare data as bytes
        Uint8List dataBytes;
        bool isTextFile = false;

        if (option == ExportDataFileOptions.backup) {
          if (response.fileContent is! Uint8List) {
            throw Exception('Invalid content type for backup file. Expected Uint8List.');
          }
          dataBytes = response.fileContent as Uint8List;
        } else {
          if (response.fileContent is! String) {
            throw Exception('Invalid content type for export file. Expected String.');
          }
          dataBytes = Uint8List.fromList((response.fileContent as String).codeUnits);
          isTextFile = true;
        }

        // Use the unified saveFile method which handles SAF on Android and file picker on desktop
        final savedPath = await _fileService.saveFile(
          fileName: response.fileName,
          data: dataBytes,
          fileExtension: response.fileExtension,
          isTextFile: isTextFile,
        );

        // Check if user canceled the save dialog
        if (savedPath == null) {
          OverlayNotificationHelper.hideNotification();
          if (context.mounted) {
            OverlayNotificationHelper.showInfo(
              context: context,
              message: _translationService.translate(SettingsTranslationKeys.exportCanceled),
            );
          }
          return;
        }

        if (context.mounted) {
          // Hide loading overlay and show success overlay notification with file path
          OverlayNotificationHelper.hideNotification();
          OverlayNotificationHelper.showSuccess(
            context: context,
            message: '${_translationService.translate(SettingsTranslationKeys.exportSuccess)}\n $savedPath',
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

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
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
      elevation: 0,
      color: AppTheme.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppTheme.sizeMedium),
        leading: StyledIcon(
          icon,
          isActive: !isDisabled,
        ),
        title: Text(
          translationService.translate(titleKey),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
      elevation: 0,
      color: AppTheme.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppTheme.sizeMedium),
        leading: StyledIcon(
          icon,
          isActive: !isDisabled,
        ),
        title: Text(
          translationService.translate(translationKey),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        onTap: isDisabled ? null : onSelect,
        enabled: !isDisabled,
      ),
    );
  }
}

class _ImportOptionTile extends StatelessWidget {
  const _ImportOptionTile({
    required this.icon,
    required this.titleKey,
    required this.descriptionKey,
    required this.onSelect,
    this.isDisabled = false,
  });

  final IconData icon;
  final String titleKey;
  final String descriptionKey;
  final VoidCallback onSelect;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: AppTheme.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppTheme.sizeMedium),
        leading: StyledIcon(
          icon,
          isActive: !isDisabled,
        ),
        title: Text(
          translationService.translate(titleKey),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          translationService.translate(descriptionKey),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        onTap: isDisabled ? null : onSelect,
        enabled: !isDisabled,
      ),
    );
  }
}

class _ExportOptionTile extends StatelessWidget {
  const _ExportOptionTile({
    required this.icon,
    this.titleKey,
    this.title,
    required this.descriptionKey,
    required this.fileOption,
    required this.onSelect,
    this.isDisabled = false,
  });

  final IconData icon;
  final String? titleKey;
  final String? title;
  final String descriptionKey;
  final ExportDataFileOptions fileOption;
  final VoidCallback onSelect;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    final theme = Theme.of(context);

    final displayTitle = title ?? (titleKey != null ? translationService.translate(titleKey!) : '');

    return Card(
      elevation: 0,
      color: AppTheme.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppTheme.sizeMedium),
        leading: StyledIcon(
          icon,
          isActive: !isDisabled,
        ),
        title: Text(
          displayTitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          translationService.translate(descriptionKey),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        onTap: isDisabled ? null : onSelect,
        enabled: !isDisabled,
      ),
    );
  }
}
