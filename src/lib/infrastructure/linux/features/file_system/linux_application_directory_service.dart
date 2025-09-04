import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_directory_service.dart';

/// Linux-specific implementation of application directory service
class LinuxApplicationDirectoryService implements IApplicationDirectoryService {
  static const String folderName = 'whph';

  @override
  Future<Directory> getApplicationDirectory() async {
    // Linux: Use ~/.local/share folder (XDG-compliant)
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw StateError('Unable to find Linux HOME directory');
    }

    final newDir = Directory(p.join(home, '.local', 'share', folderName));

    // Check for migration from old Documents location
    await _migrateFromOldLocation(newDir);

    if (kDebugMode) {
      print('LinuxApplicationDirectoryService: Using application directory: ${newDir.path}');
    }

    return newDir;
  }

  /// Migrates files from old Documents location to new standard location
  Future<void> _migrateFromOldLocation(Directory newDir) async {
    try {
      // Try to get the old Documents location
      final oldDocumentsDir = await getApplicationDocumentsDirectory();
      final oldAppDir = Directory(p.join(oldDocumentsDir.path, folderName));

      // Check if old directory exists
      if (await oldAppDir.exists()) {
        if (kDebugMode) {
          print('LinuxApplicationDirectoryService: Found old application directory at: ${oldAppDir.path}');
          print('LinuxApplicationDirectoryService: Migrating to new location: ${newDir.path}');
        }

        // Ensure new directory exists
        await newDir.create(recursive: true);

        // Migrate all files from old directory to new directory
        await for (final entity in oldAppDir.list()) {
          if (entity is File) {
            final fileName = p.basename(entity.path);
            final newFilePath = p.join(newDir.path, fileName);
            final newFile = File(newFilePath);

            // Only migrate if new file doesn't already exist
            if (!await newFile.exists()) {
              await entity.copy(newFilePath);

              if (kDebugMode) {
                print('LinuxApplicationDirectoryService: Migrated file: $fileName to ${newFile.path}');
              }
            }
          }
        }

        if (kDebugMode) {
          print('LinuxApplicationDirectoryService: Migration completed successfully');
        }

        // Optionally, you can delete the old directory after successful migration
        // await oldAppDir.delete(recursive: true);
      }
    } catch (e) {
      // Migration failure is not critical - app can continue with new location
      if (kDebugMode) {
        print('LinuxApplicationDirectoryService: Migration from old location failed (this is not critical): $e');
      }
    }
  }
}
