import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:whph/core/acore/file/abstraction/i_file_service.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';

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
      throw BusinessException('Failed to pick file: $e', SharedTranslationKeys.filePickError);
    }
  }

  @override
  Future<String?> getSavePath({
    required String fileName,
    required List<String> allowedExtensions,
    String? dialogTitle,
  }) async {
    try {
      // Check storage permissions first
      final storagePermission = await _checkStoragePermission();
      if (!storagePermission) {
        throw BusinessException(
            'Storage permission is required to save files', SharedTranslationKeys.storagePermissionError);
      }

      // On Android, FilePicker.saveFile() requires bytes, so we use getDirectoryPath instead
      // and let the user choose a directory, then we construct the full path
      final directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: dialogTitle ?? 'Choose save location',
      );

      if (directoryPath == null) {
        if (kDebugMode) debugPrint('User cancelled directory selection');
        return null;
      }

      // Construct full file path
      final fullPath = path.join(directoryPath, fileName);

      if (kDebugMode) debugPrint('Selected save path: $fullPath');
      return fullPath;
    } catch (e) {
      if (kDebugMode) debugPrint('Save path error: $e');
      throw BusinessException('Failed to get save path: $e', SharedTranslationKeys.fileSaveError);
    }
  }

  @override
  Future<String> readFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw BusinessException('File does not exist: $filePath', SharedTranslationKeys.fileNotFoundError);
      }
      return await file.readAsString();
    } catch (e) {
      throw BusinessException('Failed to read file: $e', SharedTranslationKeys.fileReadError);
    }
  }

  @override
  Future<void> writeFile({
    required String filePath,
    required String content,
  }) async {
    try {
      // Check storage permissions first
      final storagePermission = await _checkStoragePermission();
      if (!storagePermission) {
        throw BusinessException(
            'Storage permission is required to save files', SharedTranslationKeys.storagePermissionError);
      }

      final file = File(filePath);
      final dir = path.dirname(filePath);

      // Create directory if it doesn't exist
      if (!await Directory(dir).exists()) {
        await Directory(dir).create(recursive: true);
      }

      // Write the file content
      await file.writeAsString(content);

      // Verify the file was actually written
      if (!await file.exists()) {
        throw BusinessException(
            'Failed to save file: File does not exist after write operation', SharedTranslationKeys.fileSaveError);
      }

      // Verify the content was written correctly
      final writtenContent = await file.readAsString();
      if (writtenContent != content) {
        throw BusinessException(
            'Failed to save file: Content mismatch after write operation', SharedTranslationKeys.fileSaveError);
      }

      // Update file timestamp
      try {
        await file.setLastModified(DateTime.now());
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AndroidFileService]: Failed to update file timestamp: $e');
        }
      }

      if (kDebugMode) {
        debugPrint('[AndroidFileService]: Successfully saved file to: $filePath');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AndroidFileService]: Failed to write file: $e');
      }
      throw BusinessException('Failed to write file: $e', SharedTranslationKeys.fileWriteError);
    }
  }

  /// Check and request storage permissions for Android
  Future<bool> _checkStoragePermission() async {
    try {
      // For Android 13+ (API 33+), we need different permissions
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = androidInfo.version.sdkInt;

        Permission permission;
        if (sdkInt >= 33) {
          // Android 13+ uses scoped storage, but for downloads we can use MANAGE_EXTERNAL_STORAGE
          // or rely on the Downloads directory which doesn't require permissions
          permission = Permission.manageExternalStorage;
        } else {
          // Android 12 and below use WRITE_EXTERNAL_STORAGE
          permission = Permission.storage;
        }

        // Check current permission status
        final status = await permission.status;

        if (status.isGranted) {
          return true;
        }

        if (status.isDenied) {
          // Request permission
          final result = await permission.request();
          return result.isGranted;
        }

        if (status.isPermanentlyDenied) {
          throw BusinessException('Storage permission is permanently denied. Please enable it in app settings.',
              SharedTranslationKeys.storagePermissionDeniedError);
        }

        return false;
      }

      // Non-Android platforms don't need this permission
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AndroidFileService]: Error checking storage permission: $e');
      }
      return false;
    }
  }
}
