import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:whph/src/core/application/shared/services/abstraction/i_application_directory_service.dart';

/// Android-specific implementation of application directory service
class AndroidApplicationDirectoryService implements IApplicationDirectoryService {
  static const String folderName = 'whph';

  @override
  Future<Directory> getApplicationDirectory() async {
    try {
      // Android: Use application support directory
      final supportDir = await getApplicationSupportDirectory();
      final newDir = Directory(p.join(supportDir.path, folderName));

      // Check for migration from old Documents location
      await _migrateFromOldLocation(newDir);

      if (kDebugMode) {
        print('AndroidApplicationDirectoryService: Using application directory: ${newDir.path}');
      }

      return newDir;
    } catch (e) {
      throw StateError('Unable to get Android application support directory: $e');
    }
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
          print('AndroidApplicationDirectoryService: Found old application directory at: ${oldAppDir.path}');
          print('AndroidApplicationDirectoryService: Migrating to new location: ${newDir.path}');
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
                print('AndroidApplicationDirectoryService: Migrated file: $fileName to ${newFile.path}');
              }
            }
          }
        }

        if (kDebugMode) {
          print('AndroidApplicationDirectoryService: Migration completed successfully');
        }

        // Optionally, you can delete the old directory after successful migration
        // await oldAppDir.delete(recursive: true);
      }
    } catch (e) {
      // Migration failure is not critical - app can continue with new location
      if (kDebugMode) {
        print('AndroidApplicationDirectoryService: Migration from old location failed (this is not critical): $e');
      }
    }
  }
}
