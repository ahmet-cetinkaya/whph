import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:whph/src/core/application/shared/services/abstraction/i_logger_service.dart';
import 'package:whph/src/core/application/shared/services/abstraction/i_log_export_service.dart';
import 'package:whph/src/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/settings/constants/settings_translation_keys.dart';

class DebugLogsPage extends StatefulWidget {
  static const String route = '/settings/advanced/debug-logs';

  const DebugLogsPage({super.key});

  @override
  State<DebugLogsPage> createState() => _DebugLogsPageState();
}

class _DebugLogsPageState extends State<DebugLogsPage> {
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
        
        // Try to read from file first (if available)
        String fileContent = '';
        if (logFilePath != null) {
          final logFile = File(logFilePath);
          if (await logFile.exists()) {
            try {
              fileContent = await logFile.readAsString();
            } catch (e) {
              // Ignore file reading errors, fallback to memory
            }
          }
        }
        
        // Get memory logs as fallback or supplement
        final memoryContent = _loggerService.getMemoryLogs();
        
        // Combine file content and memory content
        if (fileContent.isNotEmpty && memoryContent.isNotEmpty) {
          _logContent = '$fileContent\n--- Current Session ---\n$memoryContent';
        } else if (fileContent.isNotEmpty) {
          _logContent = fileContent;
        } else if (memoryContent.isNotEmpty) {
          _logContent = memoryContent;
        } else {
          _logContent = _translationService.translate(SettingsTranslationKeys.debugLogsEmpty);
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
        
        String contentToExport = '';
        
        // Try to read from file first
        if (_logFilePath != null) {
          final logFile = File(_logFilePath!);
          if (await logFile.exists()) {
            try {
              contentToExport = await logFile.readAsString();
            } catch (e) {
              // File read failed, use memory content
            }
          }
        }
        
        // If no file content, use memory logs
        if (contentToExport.isEmpty) {
          contentToExport = _loggerService.getMemoryLogs();
          if (contentToExport.isEmpty) {
            throw Exception("No log content available to export.");
          }
          
          // Create a temporary file for memory logs export
          final appDirectory = await _loggerService.getLogFilePath();
          final tempDir = appDirectory != null ? path.dirname(appDirectory) : '/tmp';
          final tempFilePath = path.join(tempDir, 'whph_memory_logs.txt');
          final tempFile = File(tempFilePath);
          await tempFile.writeAsString(contentToExport);
          
          // Export the temporary file
          final exportedPath = await _logExportService.exportLogFile(tempFilePath);
          
          // Clean up temp file
          try {
            await tempFile.delete();
          } catch (e) {
            // Ignore cleanup errors
          }
          
          if (exportedPath != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${_translationService.translate(SettingsTranslationKeys.exportLogsSuccess)}: $exportedPath'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } else {
          // Export the existing log file
          final exportedPath = await _logExportService.exportLogFile(_logFilePath!);
          
          if (exportedPath != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${_translationService.translate(SettingsTranslationKeys.exportLogsSuccess)}: $exportedPath'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
        
        return true;
      },
    );
  }

  Future<void> _copyToClipboard() async {
    if (_logContent.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: _logContent));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_translationService.translate(SettingsTranslationKeys.debugLogsCopied)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: _themeService.themeChanges,
      builder: (context, snapshot) {
        final theme = Theme.of(context);

        return ResponsiveScaffoldLayout(
          title: _translationService.translate(SettingsTranslationKeys.debugLogsPageTitle),
          appBarActions: [
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
          ],
          builder: (context) => Padding(
            padding: const EdgeInsets.all(AppTheme.sizeSmall),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Log content
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.sizeSmall),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.terminal,
                                      color: theme.colorScheme.onSurface,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _translationService.translate(SettingsTranslationKeys.debugLogsContent),
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    if (_logFilePath != null) ...[
                                      const Spacer(),
                                      Text(
                                        _logFilePath!.split('/').last,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: AppTheme.sizeSmall),
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