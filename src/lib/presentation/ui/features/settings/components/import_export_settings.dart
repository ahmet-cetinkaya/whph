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
              title: Text(
                _translationService.translate(SettingsTranslationKeys.importExportTitle),
                style: AppTheme.headlineSmall,
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_pageController.hasClients && _pageController.page! > 0) {
                    _navigateToPage(0);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
              elevation: 0,
            ),
            body: SafeArea(
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
            onTap: () => _navigateToPage(2),
            isDisabled: _isProcessing,
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
                      _navigateToPage(0);
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
              onPressed: () => _navigateToPage(0),
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
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            translationService.translate(descriptionKey),
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: isDisabled ? theme.disabledColor : theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        onTap: !isDisabled ? onSelect : null,
        enabled: !isDisabled,
      ),
    );
  }
}
