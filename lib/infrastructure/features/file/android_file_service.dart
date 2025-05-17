import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:whph/core/acore/file/abstraction/i_file_service.dart';
import 'package:whph/core/acore/errors/business_exception.dart';

class AndroidFileService implements IFileService {
  @override
  Future<String?> pickFile({
    List<String>? allowedExtensions,
    String? dialogTitle,
  }) async {
    try {
      if (kDebugMode) debugPrint('Starting file pick with extensions: $allowedExtensions');

      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        dialogTitle: dialogTitle,
        withData: true,
      );

      // ...existing code for pickFile...
      return result?.files.firstOrNull?.path;
    } catch (e) {
      if (kDebugMode) debugPrint('File pick error: $e');
      throw BusinessException('Failed to pick file: $e');
    }
  }

  @override
  Future<String?> getSavePath({
    required String fileName,
    required List<String> allowedExtensions,
    String? dialogTitle,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      return path.join(tempDir.path, fileName);
    } catch (e) {
      if (kDebugMode) debugPrint('Save path error: $e');
      throw BusinessException('Failed to get save path: $e');
    }
  }

  @override
  Future<String> readFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw BusinessException('File does not exist: $filePath');
      }
      return await file.readAsString();
    } catch (e) {
      throw BusinessException('Failed to read file: $e');
    }
  }

  @override
  Future<void> writeFile({
    required String filePath,
    required String content,
  }) async {
    try {
      final fileName = path.basename(filePath);
      final downloadsPath = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(downloadsPath.path);

      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final file = File(path.join(downloadsDir.path, fileName));
      await file.writeAsString(content);

      try {
        await file.setLastModified(DateTime.now());
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AndroidFileService]: Failed to update file timestamp: $e');
        }
      }
    } catch (e) {
      throw BusinessException('Failed to write file: $e');
    }
  }
}
