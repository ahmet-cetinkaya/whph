import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:whph/src/core/application/shared/services/abstraction/i_logger_service.dart';
import 'package:whph/src/core/application/shared/services/abstraction/i_log_export_service.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/settings/constants/settings_translation_keys.dart';

class DebugLogsContent extends StatefulWidget {
  const DebugLogsContent({super.key});

  @override
  State<DebugLogsContent> createState() => _DebugLogsContentState();
}

class _DebugLogsContentState extends State<DebugLogsContent> {
  final _loggerService = container.resolve<ILoggerService>();
  final _logExportService = container.resolve<ILogExportService>();
  final _translationService = container.resolve<ITranslationService>();

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

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _logContent));
    if (mounted) {
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_translationService.translate(SettingsTranslationKeys.debugLogsCopied)),
          backgroundColor: theme.colorScheme.tertiary,
        ),
      );
    }
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
          final tempDir = await getTemporaryDirectory();
          final tempFilePath = path.join(tempDir.path, 'whph_memory_logs.txt');
          final tempFile = File(tempFilePath);
          await tempFile.writeAsString(contentToExport);
          
          // Export the temporary file
          final exportedPath = await _logExportService.exportLogFile(tempFilePath);
          
          // Clean up temporary file
          try {
            await tempFile.delete();
          } catch (e) {
            // Ignore cleanup errors
          }
          
          if (exportedPath != null && mounted) {
            final theme = Theme.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_translationService.translate(SettingsTranslationKeys.exportLogsSuccess)),
                backgroundColor: theme.colorScheme.tertiary,
              ),
            );
          }
        } else {
          // Export existing log file
          final exportedPath = await _logExportService.exportLogFile(_logFilePath!);
          if (exportedPath != null && mounted) {
            final theme = Theme.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_translationService.translate(SettingsTranslationKeys.exportLogsSuccess)),
                backgroundColor: theme.colorScheme.tertiary,
              ),
            );
          }
        }

        return true;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action buttons
        Padding(
          padding: const EdgeInsets.all(AppTheme.sizeMedium),
          child: Wrap(
            spacing: AppTheme.sizeSmall,
            runSpacing: AppTheme.sizeSmall,
            children: [
              ElevatedButton.icon(
                onPressed: _isExporting ? null : _refreshLogs,
                icon: const Icon(Icons.refresh),
                label: Text(_translationService.translate(SettingsTranslationKeys.debugLogsRefresh)),
              ),
              ElevatedButton.icon(
                onPressed: _logContent.isNotEmpty ? _copyToClipboard : null,
                icon: const Icon(Icons.copy),
                label: Text(_translationService.translate(SettingsTranslationKeys.debugLogsCopy)),
              ),
              ElevatedButton.icon(
                onPressed: _isExporting || _logContent.isEmpty ? null : _saveAsFile,
                icon: _isExporting 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_alt),
                label: Text(_translationService.translate(SettingsTranslationKeys.debugLogsSaveAs)),
              ),
            ],
          ),
        ),

        // Log content area
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(AppTheme.sizeMedium),
            padding: const EdgeInsets.all(AppTheme.sizeMedium),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
              color: theme.colorScheme.surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Content header
                Text(
                  _translationService.translate(SettingsTranslationKeys.debugLogsContent),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.sizeSmall),

                // Log content
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _logContent,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
