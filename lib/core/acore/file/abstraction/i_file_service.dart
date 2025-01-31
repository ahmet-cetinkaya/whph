abstract class IFileService {
  Future<String?> pickFile({
    List<String>? allowedExtensions,
    String? dialogTitle,
  });

  Future<String?> getSavePath({
    required String fileName,
    required List<String> allowedExtensions,
    String? dialogTitle,
  });

  Future<String> readFile(String filePath);

  Future<void> writeFile({
    required String filePath,
    required String content,
  });
}
