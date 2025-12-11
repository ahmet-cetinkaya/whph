import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:path/path.dart' as path;
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

class AndroidFileService implements IFileService {
  @override
  Future<String?> pickFile({
    List<String>? allowedExtensions,
    String? dialogTitle,
  }) async {
    try {
      Logger.debug('Starting file pick with extensions: $allowedExtensions');

      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        dialogTitle: dialogTitle,
        withData: true,
      );

      return result?.files.firstOrNull?.path;
    } catch (e) {
      Logger.error('File pick error: $e');
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
      // Deprecated: Use saveFile() instead for SAF support
      // This method is kept for backward compatibility with internal file operations
      final file = File(filePath);
      final dir = path.dirname(filePath);

      if (!await Directory(dir).exists()) {
        await Directory(dir).create(recursive: true);
      }

      await file.writeAsString(content);

      Logger.debug('[AndroidFileService]: Successfully wrote file to: $filePath');
    } catch (e) {
      Logger.error('[AndroidFileService]: Failed to write file: $e');
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
      // Deprecated: Use saveFile() instead for SAF support
      // This method is kept for backward compatibility with internal file operations
      final file = File(filePath);
      final dir = path.dirname(filePath);

      if (!await Directory(dir).exists()) {
        await Directory(dir).create(recursive: true);
      }

      await file.writeAsBytes(data);

      Logger.debug('[AndroidFileService]: Successfully wrote binary file to: $filePath (${data.length} bytes)');
    } catch (e) {
      Logger.error('[AndroidFileService]: Failed to write binary file: $e');
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
      Logger.debug('[AndroidFileService]: Saving file using SAF: $fileName (${data.length} bytes)');

      final savedPath = await FileSaver.instance.saveAs(
        name: path.basenameWithoutExtension(fileName),
        bytes: data,
        ext: fileExtension,
        mimeType: isTextFile ? MimeType.text : MimeType.other,
      );

      if (savedPath == null) {
        Logger.debug('[AndroidFileService]: User cancelled file save');
        return null;
      }

      Logger.debug('[AndroidFileService]: Successfully saved file via SAF: $savedPath');
      return savedPath;
    } catch (e) {
      Logger.error('[AndroidFileService]: Failed to save file: $e');
      throw BusinessException('Failed to save file: $e', SharedTranslationKeys.fileSaveError);
    }
  }
}
