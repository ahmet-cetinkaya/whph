import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';

class DesktopFileService implements IFileService {
  @override
  Future<String?> pickFile({
    List<String>? allowedExtensions,
    String? dialogTitle,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        dialogTitle: dialogTitle,
      );

      return result?.files.firstOrNull?.path;
    } catch (e) {
      throw BusinessException('Failed to pick file: $e', SharedTranslationKeys.filePickError);
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
      final file = File(filePath);
      final dir = path.dirname(filePath);

      if (!await Directory(dir).exists()) {
        await Directory(dir).create(recursive: true);
      }

      await file.writeAsString(content);
    } catch (e) {
      throw BusinessException('Failed to write file: $e', SharedTranslationKeys.fileWriteError);
    }
  }

  @override
  Future<Uint8List> readBinaryFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw BusinessException('File does not exist: $filePath', SharedTranslationKeys.fileNotFoundError);
      }
      return await file.readAsBytes();
    } catch (e) {
      throw BusinessException('Failed to read binary file: $e', SharedTranslationKeys.fileReadError);
    }
  }

  @override
  Future<void> writeBinaryFile({
    required String filePath,
    required Uint8List data,
  }) async {
    try {
      final file = File(filePath);
      final dir = path.dirname(filePath);

      if (!await Directory(dir).exists()) {
        await Directory(dir).create(recursive: true);
      }

      await file.writeAsBytes(data);

      // Verify the file was actually written
      if (!await file.exists()) {
        throw BusinessException('Failed to save binary file: File does not exist after write operation',
            SharedTranslationKeys.fileSaveError);
      }

      // Verify the content was written correctly by checking file size
      if (await file.length() != data.length) {
        throw BusinessException('Failed to save binary file: Data length mismatch after write operation',
            SharedTranslationKeys.fileSaveError);
      }
    } catch (e) {
      throw BusinessException('Failed to write binary file: $e', SharedTranslationKeys.fileWriteError);
    }
  }

  @override
  Future<String?> saveFile({
    required String fileName,
    required Uint8List data,
    required String fileExtension,
    bool isTextFile = false,
  }) async {
    try {
      // Use traditional file picker on desktop
      final savePath = await FilePicker.platform.saveFile(
        fileName: fileName,
        allowedExtensions: [fileExtension],
        type: FileType.custom,
      );

      if (savePath == null) {
        return null; // User cancelled
      }

      // Write the file
      final file = File(savePath);
      final dir = path.dirname(savePath);

      if (!await Directory(dir).exists()) {
        await Directory(dir).create(recursive: true);
      }

      await file.writeAsBytes(data);

      return savePath;
    } catch (e) {
      throw BusinessException('Failed to save file: $e', SharedTranslationKeys.fileSaveError);
    }
  }
}
