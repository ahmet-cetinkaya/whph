// T20 acceptance 2 (backup holds no private or epoch key) and 7 (Android
// backup XML references the key file).
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:whph/infrastructure/persistence/shared/contexts/drift/database_backup_service.dart';
import 'package:whph/infrastructure/shared/features/sync/file_sync_key_store.dart';

import '../../../persistence/shared/contexts/drift/wal_test_support.dart';
import 'sync_security_test_support.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

bool _contains(List<int> haystack, List<int> needle) {
  final text = latin1.decode(haystack);
  return text.contains(latin1.decode(needle));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('backup (acc 2)', () {
    late Directory temp;
    late SecurityDevice a;
    late SecurityDevice b;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('t20-backup-');
      a = await SecurityDevice.open('a', temp);
      b = await SecurityDevice.open('b', temp);
      await pairDevices(a, b);
      await a.database.insertNote('n1', 'user data');
      await syncDevices(a, b);
    });

    tearDown(() async {
      await a.close();
      await b.close();
      await temp.delete(recursive: true);
    });

    test(
        'the backup holds no private key or epoch key in hex or base64; the key file does',
        () async {
      final secrets = <String, List<int>>{
        'x25519 private': a.membership.snapshotKeyFile().x25519Private,
        'ed25519 seed': a.membership.snapshotKeyFile().ed25519Seed,
        for (final entry in a.membership.snapshotKeyFile().epochKeys.entries)
          'epoch ${entry.key}': entry.value,
      };
      expect(secrets.length, greaterThanOrEqualTo(3),
          reason: 'an epoch key exists after pairing');
      final service = DatabaseBackupService(
          getApplicationDirectory: () async => temp, databaseName: 'app.db');

      final backup = await service.createConsistentSnapshot(
        writeSnapshot: (path) =>
            a.database.db.customStatement(vacuumIntoStatement(path)),
        destination: File(p.join(temp.path, 'backup.db')),
      );

      final backupBytes = await backup.readAsBytes();
      final keyFileBytes = await a.keyStore.keyFile.readAsBytes();
      for (final entry in secrets.entries) {
        final spellings = {
          'hex': ascii.encode(_hex(entry.value)),
          'base64': ascii.encode(base64Encode(entry.value))
        };
        for (final spelling in spellings.entries) {
          expect(_contains(backupBytes, spelling.value), isFalse,
              reason: '${entry.key} (${spelling.key}) in backup');
        }
        expect(
            _contains(keyFileBytes, spellings['base64']!) ||
                _contains(keyFileBytes, spellings['hex']!),
            isTrue,
            reason: 'control: ${entry.key} is searchable in the key file');
      }
      expect(
          _contains(backupBytes,
              ascii.encode(_hex(a.membership.identity.ed25519Pub))),
          isTrue,
          reason: 'own public keys are synced by design');
    });

    test('a snapshot cannot be written over the key file or the ledger',
        () async {
      final service = DatabaseBackupService(
          getApplicationDirectory: () async => temp, databaseName: 'app.db');

      for (final name in [keyFileName, ledgerFileName]) {
        await expectLater(
          service.createConsistentSnapshot(
              writeSnapshot: (_) async {},
              destination: File(p.join(temp.path, name))),
          throwsA(isA<StateError>()),
        );
      }
    });
  });

  group('Android backup rules (acc 7)', () {
    final resources = Directory('android/app/src/main/res/xml');

    test(
        'fullBackupContent excludes the key file for release and debug data folders',
        () {
      final xml =
          File(p.join(resources.path, 'backup_rules.xml')).readAsStringSync();

      expect(xml, contains('<full-backup-content>'));
      expect(
          RegExp('<exclude domain="file" path="[^"]*$keyFileName" */>')
              .allMatches(xml)
              .length,
          2);
      expect(xml, contains('whph/$keyFileName'));
      expect(xml, contains('debug_whph/$keyFileName'));
    });

    test(
        'dataExtractionRules excludes the key file from cloud backup and device transfer',
        () {
      final xml = File(p.join(resources.path, 'data_extraction_rules.xml'))
          .readAsStringSync();

      for (final section in ['cloud-backup', 'device-transfer']) {
        final block = RegExp('<$section[^>]*>(.*?)</$section>', dotAll: true)
            .firstMatch(xml);
        expect(block, isNotNull, reason: section);
        expect(block!.group(1), contains(keyFileName), reason: section);
      }
    });

    test('the manifest references both rule files', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

      expect(manifest,
          contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
      expect(
          manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    });
  });
}
