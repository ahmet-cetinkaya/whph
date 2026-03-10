import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import 'package:whph/core/application/shared/services/abstraction/i_log_export_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/main.dart';
import 'package:acore/acore.dart';

/// Default implementation of ILogExportService
///
/// This service handles exporting log files to user-selected locations
/// across different platforms (desktop, mobile, web)
class LogExportService implements ILogExportService {
  /// Generate a timestamped filename for log export
  String _generateSuggestedFileName(String logFilePath) {
    final fileName = path.basename(logFilePath);
    final fileExtension = path.extension(fileName);
    final baseName = path.basenameWithoutExtension(fileName);

    // Generate a timestamped filename
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    return '${baseName}_$timestamp$fileExtension';
  }

  @override
  Future<String?> exportLogFile(String logFilePath) async {
    try {
      final logFile = File(logFilePath);

      // Check if log file exists
      if (!await logFile.exists()) {
        throw Exception("Log file does not exist: $logFilePath");
      }

      if (PlatformUtils.isDesktop) {
        return await _exportOnDesktop(logFile);
      } else if (PlatformUtils.isMobile) {
        return await _exportOnMobile(logFile);
      } else {
        throw Exception("Unsupported platform for log export");
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Export log file on desktop platforms using file picker
  Future<String?> _exportOnDesktop(File logFile) async {
    try {
      final translationService = container.resolve<ITranslationService>();
      final suggestedName = _generateSuggestedFileName(logFile.path);

      // Show save dialog with localized title
      final result = await FilePicker.platform.saveFile(
        dialogTitle: translationService.translate(SettingsTranslationKeys.exportLogsDialogTitle),
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: ['log', 'txt'],
      );

      if (result != null) {
        // Copy the log file to the selected destination
        final destinationFile = File(result);
        await logFile.copy(result);
        return destinationFile.path;
      }

      return null; // User cancelled
    } catch (e) {
      throw Exception("Failed to export log file on desktop: $e");
    }
  }

  /// Export log file on mobile platforms using share sheet
  Future<String?> _exportOnMobile(File logFile) async {
    try {
      // Use share_plus to share the file directly
      // This avoids reading the entire file into memory which causes crashes with large logs
      final xFile = XFile(logFile.path);

      // We don't get a result path back from share, but we know the operation was initiated
      // The share sheet will handle the rest
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: 'Debug Logs',
        ),
      );

      return "Shared via system dialog";
    } catch (e) {
      throw Exception("Failed to export log file on mobile: $e");
    }
  }
}
