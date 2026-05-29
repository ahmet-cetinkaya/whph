import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_directory_service.dart';

/// Windows-specific implementation of application directory service
class WindowsApplicationDirectoryService implements IApplicationDirectoryService {
  static const String folderName = 'whph';

  /// Get the folder name with debug prefix if in debug mode
  String get _folderName => kDebugMode ? 'debug_$folderName' : folderName;

  @override
  Future<Directory> getApplicationDirectory() async {
    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) {
      throw StateError('Unable to find Windows AppData directory');
    }

    final newDir = Directory(p.join(appData, _folderName));

    await _migrateFromOldLocation(newDir);

    if (kDebugMode) {
      print('WindowsApplicationDirectoryService: Using application directory: ${newDir.path}');
    }

    return newDir;
  }

  /// Migrates files from old Documents location to new standard location
  Future<void> _migrateFromOldLocation(Directory newDir) async {
    try {
      final oldDocumentsDir = await getApplicationDocumentsDirectory();
      final oldAppDir = Directory(p.join(oldDocumentsDir.path, folderName));

      if (await oldAppDir.exists()) {
        if (kDebugMode) {
          print('WindowsApplicationDirectoryService: Found old application directory at: ${oldAppDir.path}');
          print('WindowsApplicationDirectoryService: Migrating to new location: ${newDir.path}');
        }

        await newDir.create(recursive: true);

        await for (final entity in oldAppDir.list()) {
          if (entity is File) {
            final fileName = p.basename(entity.path);
            final newFilePath = p.join(newDir.path, fileName);
            final newFile = File(newFilePath);

            if (!await newFile.exists()) {
              await entity.copy(newFilePath);

              if (kDebugMode) {
                print('WindowsApplicationDirectoryService: Migrated file: $fileName to ${newFile.path}');
              }
            }
          }
        }

        if (kDebugMode) {
          print('WindowsApplicationDirectoryService: Migration completed successfully');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('WindowsApplicationDirectoryService: Migration from old location failed (this is not critical): $e');
      }
    }
  }
}
