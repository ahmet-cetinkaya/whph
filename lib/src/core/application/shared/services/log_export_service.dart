import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:path/path.dart' as path;
import 'package:whph/src/core/application/shared/services/abstraction/i_log_export_service.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/features/settings/constants/settings_translation_keys.dart';
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
      } else if (PlatformUtils.isWeb) {
        return await _exportOnWeb(logFile);
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

  /// Export log file on mobile platforms using file saver
  Future<String?> _exportOnMobile(File logFile) async {
    try {
      final suggestedName = _generateSuggestedFileName(logFile.path);
      final fileExtension = path.extension(logFile.path);

      // Read file content
      final fileContent = await logFile.readAsBytes();

      // Save file to Downloads directory
      final savedPath = await FileSaver.instance.saveAs(
        name: suggestedName,
        bytes: fileContent,
        ext: fileExtension.replaceFirst('.', ''),
        mimeType: MimeType.text,
      );

      return savedPath;
    } catch (e) {
      throw Exception("Failed to export log file on mobile: $e");
    }
  }

  /// Export log file on web platform using file saver
  Future<String?> _exportOnWeb(File logFile) async {
    try {
      final suggestedName = _generateSuggestedFileName(logFile.path);
      final fileExtension = path.extension(logFile.path);

      // Read file content
      final fileContent = await logFile.readAsBytes();

      // Trigger browser download using FileSaver
      final savedPath = await FileSaver.instance.saveAs(
        name: suggestedName,
        bytes: fileContent,
        ext: fileExtension.replaceFirst('.', ''),
        mimeType: MimeType.text,
      );

      return savedPath ?? suggestedName; // Return filename if path not available on web
    } catch (e) {
      throw Exception("Failed to export log file on web: $e");
    }
  }
}
