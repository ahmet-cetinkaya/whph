import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:whph/corePackages/acore/file/abstraction/i_file_service.dart';
import 'package:whph/corePackages/acore/errors/business_exception.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_translation_keys.dart';

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
  Future<String?> getSavePath({
    required String fileName,
    required List<String> allowedExtensions,
    String? dialogTitle,
  }) async {
    try {
      return await FilePicker.platform.saveFile(
        fileName: fileName,
        allowedExtensions: allowedExtensions,
        type: FileType.custom,
        dialogTitle: dialogTitle,
      );
    } catch (e) {
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
}
