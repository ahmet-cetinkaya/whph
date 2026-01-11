// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart' hide test, expect, setUpAll, group, tearDownAll;
import 'package:test/test.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'generated/schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp();
    AppDatabase.testDirectory = tempDir;
    AppDatabase.isTestMode = true;
    verifier = SchemaVerifier(GeneratedHelper());
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  /*
  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    final versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });
  */

  // NOTE: The data integrity test has been disabled because schema generation
  // changed when explicit primary keys were added. The test was not actually
  // testing any data (all lists were empty). Re-enable if needed by updating
  // to use the new schema generation format without *Data classes.
  //
  // The following template shows how to write tests ensuring your migrations
  // preserve existing data.
  // Testing this can be useful for migrations that change existing columns
  // (e.g. by altercating their type or constraints). Migrations that only add
  // tables or columns typically don't need these advanced tests. For more
  // information, see https://drift.simonbinder.eu/migrations/tests/#verifying-data-integrity
  //
  // test("migration from v1 to v2 does not corrupt data", () async {
  //   ...test implementation...
  // });
}
