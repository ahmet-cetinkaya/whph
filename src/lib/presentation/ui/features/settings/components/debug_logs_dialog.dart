import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whph/core/application/shared/services/abstraction/i_logger_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_log_export_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';

class DebugLogsDialog extends StatefulWidget {
  const DebugLogsDialog({super.key});

  @override
  State<DebugLogsDialog> createState() => _DebugLogsDialogState();
}

class _DebugLogsDialogState extends State<DebugLogsDialog> {
  final _loggerService = container.resolve<ILoggerService>();
  final _logExportService = container.resolve<ILogExportService>();
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  String _logContent = '';
  bool _isLoading = true;
  bool _isExporting = false;
  String? _logFilePath;

  @override
  void initState() {
    super.initState();
    _loadLogContent();
  }

  Future<void> _loadLogContent() async {
    await AsyncErrorHandler.executeWithLoading(
      context: context,
      setLoading: (isLoading) => setState(() {
        _isLoading = isLoading;
      }),
      errorMessage: _translationService.translate(SettingsTranslationKeys.debugLogsLoadError),
      operation: () async {
        final logFilePath = await _loggerService.getLogFilePath();
        _logFilePath = logFilePath;

        // Always flush current logs before reading
        await _loggerService.flush();

        // Try to read debug logs from file first, then fallback to memory logs
        if (logFilePath != null) {
          final logFile = File(logFilePath);
          if (await logFile.exists()) {
            try {
              _logContent = await logFile.readAsString();
            } catch (e) {
              _logContent = 'Error reading log file: $e';
            }
          } else {
            _logContent = _translationService.translate(SettingsTranslationKeys.debugLogsNoFile);
          }
        } else {
          _logContent = _translationService.translate(SettingsTranslationKeys.debugLogsNotEnabled);
        }

        // If file is empty or debug logging is disabled, fallback to memory logs
        if (_logContent.trim().isEmpty || logFilePath == null) {
          final memoryLogs = _loggerService.getMemoryLogs();
          if (memoryLogs.isNotEmpty) {
            _logContent = memoryLogs;
          } else if (_logContent.trim().isEmpty) {
            _logContent = _translationService.translate(SettingsTranslationKeys.debugLogsEmpty);
          }
        }

        return true;
      },
    );
  }

  Future<void> _refreshLogs() async {
    await _loadLogContent();
  }

  Future<void> _saveAsFile() async {
    if (_isExporting) return;

    await AsyncErrorHandler.executeWithLoading(
      context: context,
      setLoading: (isLoading) => setState(() {
        _isExporting = isLoading;
      }),
      errorMessage: _translationService.translate(SettingsTranslationKeys.exportLogsError),
      operation: () async {
        // Flush current logs before export
        await _loggerService.flush();

        String? exportedPath;

        if (_logFilePath != null) {
          // Debug logs are stored in file, export directly from file
          final logFile = File(_logFilePath!);
          if (await logFile.exists()) {
            exportedPath = await _logExportService.exportLogFile(_logFilePath!);
          } else {
            throw Exception(_translationService.translate(SettingsTranslationKeys.exportLogsFileNotExist));
          }
        } else {
          // Debug logging is disabled, export memory logs
          final memoryLogs = _loggerService.getMemoryLogs();
          if (memoryLogs.isEmpty) {
            throw Exception(_translationService.translate(SettingsTranslationKeys.exportLogsNoLogsAvailable));
          }

          // Create a temporary file with memory logs
          final tempDir = Directory.systemTemp;
          final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
          final tempLogFile = File('${tempDir.path}/whph_memory_logs_$timestamp.log');

          await tempLogFile.writeAsString(memoryLogs);

          try {
            exportedPath = await _logExportService.exportLogFile(tempLogFile.path);
          } finally {
            // Clean up temporary file
            if (await tempLogFile.exists()) {
              await tempLogFile.delete();
            }
          }
        }

        if (exportedPath != null && mounted) {
          OverlayNotificationHelper.showSuccess(
            context: context,
            message: '${_translationService.translate(SettingsTranslationKeys.exportLogsSuccess)}: $exportedPath',
            duration: const Duration(seconds: 5),
          );
        }

        return true;
      },
    );
  }

  Future<void> _copyToClipboard() async {
    if (_logContent.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: _logContent));

    if (mounted) {
      OverlayNotificationHelper.showInfo(
        context: context,
        message: _translationService.translate(SettingsTranslationKeys.debugLogsCopied),
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: _themeService.themeChanges,
      builder: (context, snapshot) {
        final theme = Theme.of(context);

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              _translationService.translate(SettingsTranslationKeys.debugLogsPageTitle),
              style: AppTheme.headlineSmall,
            ),
            elevation: 0,
            actions: [
              // Refresh button
              IconButton(
                onPressed: _isLoading ? null : _refreshLogs,
                icon: const Icon(Icons.refresh),
                tooltip: _translationService.translate(SettingsTranslationKeys.debugLogsRefresh),
              ),
              // Copy to clipboard button
              IconButton(
                onPressed: _logContent.isEmpty ? null : _copyToClipboard,
                icon: const Icon(Icons.copy),
                tooltip: _translationService.translate(SettingsTranslationKeys.debugLogsCopy),
              ),
              // Save as file button (show if there's any log content)
              if (_logContent.isNotEmpty)
                IconButton(
                  onPressed: _isExporting ? null : _saveAsFile,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt),
                  tooltip: _translationService.translate(SettingsTranslationKeys.debugLogsSaveAs),
                ),
              const SizedBox(width: AppTheme.sizeSmall),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(AppTheme.sizeLarge),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Log content
                      Expanded(
                        child: Card(
                          elevation: 0,
                          color: AppTheme.surface1,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.sizeMedium),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    StyledIcon(
                                      Icons.terminal,
                                      isActive: true,
                                    ),
                                    const SizedBox(width: AppTheme.sizeMedium),
                                    Text(
                                      _translationService.translate(SettingsTranslationKeys.debugLogsContent),
                                      style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    if (_logFilePath != null) ...[
                                      const Spacer(),
                                      Text(
                                        _logFilePath!.split('/').last,
                                        style: AppTheme.bodySmall.copyWith(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: AppTheme.sizeMedium),
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: theme.colorScheme.outline.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(AppTheme.sizeSmall),
                                      child: SelectableText(
                                        _logContent,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
