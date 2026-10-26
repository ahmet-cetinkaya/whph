// T26 acceptance 1-5 (FR-027, FR-051): after a real two-device pairing and
// sync, no key material, pairing token or SAS code reaches the export, the
// database or the captured log, and an import never creates members or keys.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/notes/commands/normalize_note_orders_command.dart';
import 'package:whph/core/application/features/settings/commands/export_data_command.dart';
import 'package:whph/core/application/features/settings/commands/import_data_command.dart';
import 'package:whph/core/application/features/tasks/commands/normalize_task_orders_command.dart';
import 'package:whph/core/application/features/habits/commands/normalize_habit_orders_command.dart';
import 'package:whph/core/application/shared/services/compression_service.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/infrastructure/persistence/features/notes/repositories/drift_note_repository.dart';
import 'package:whph/infrastructure/persistence/features/notes/repositories/drift_note_tag_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/main.mapper.g.dart' show initializeJsonMapper;
import 'package:whph_sync_core/whph_sync_core.dart';

import '../../core/application/features/settings/commands/import_data_command_test.mocks.dart';
import '../../infrastructure/shared/features/sync/sync_security_test_support.dart';

const int _markerCount = 50;
const String _markerPrefix = 'T26-MARKER-';
const String _importedNoteId = 'imported-note';
const String _importedTitle = 'T26-IMPORTED';

void main() {
  late Directory root;
  late SecurityDevice deviceA;
  late SecurityDevice deviceB;
  late List<String> logLines;
  late List<_Secret> secrets;
  late Uint8List exportJson;
  late Uint8List exportCsv;
  late Uint8List exportBackup;

  setUpAll(() async {
    initializeJsonMapper();
    root = await Directory.systemTemp.createTemp('t26-redaction-');
    deviceA = await SecurityDevice.open('A', root);
    deviceB = await SecurityDevice.open('B', root);
    logLines = [];

    await runZoned(() async {
      await pairDevices(deviceA, deviceB);
      for (var i = 0; i < _markerCount; i++) {
        await deviceA.database.insertNote('marker-$i', '$_markerPrefix$i');
      }
      await syncDevices(deviceA, deviceB);
    },
        zoneSpecification:
            ZoneSpecification(print: (_, __, ___, line) => logLines.add(line)));

    secrets = [
      ...await _keySecrets(deviceA),
      ...await _keySecrets(deviceB),
      _Secret.bytes('pairing token',
          PairingToken.generate(now: DateTime.now()).exportForQr()),
      _Secret.text(
          'SAS code', sasCode(_filled(32, 1), _filled(16, 2), _filled(16, 3))),
    ];

    final exports = _SettingsHandlers.over(deviceA.database.db);
    exportJson = _asBytes((await exports.export
            .call(ExportDataCommand(ExportDataFileOptions.json)))
        .fileContent);
    exportBackup = _asBytes((await exports.export
            .call(ExportDataCommand(ExportDataFileOptions.backup)))
        .fileContent);
    exportCsv = _asBytes((await exports.export
            .call(ExportDataCommand(ExportDataFileOptions.csv)))
        .fileContent);
  });

  tearDownAll(() async {
    AppDatabase.resetInstance();
    await deviceA.close();
    await deviceB.close();
    await root.delete(recursive: true);
  });

  test(
      'the session ran: all markers reached the second device and it is paired',
      () async {
    final received = await deviceB.database.count(
        "SELECT COUNT(*) FROM note_table WHERE title LIKE '$_markerPrefix%'");
    expect(received, _markerCount);
    expect((await deviceB.service.currentView()).isPaired, isTrue);
  });

  test('control: the scanner finds a planted key in every spelling', () {
    final key = _filled(32, 9);
    final planted = _Secret.bytes('planted', key);
    for (final spelling in planted.needles) {
      expect(_findLeaks(Uint8List.fromList([1, 2, ...spelling, 3]), [planted]),
          ['planted']);
    }
  });

  test('acceptance 1: export has no key, token or SAS code and no sync rows',
      () {
    for (final export in [exportJson, exportCsv]) {
      expect(_findLeaks(export, secrets), isEmpty);
      final text = utf8.decode(export).toLowerCase();
      for (final syncWord in [
        'syncdevices',
        'sync_member',
        'sync_origin',
        'sync_epoch',
        'sync_grant',
        'sync_manifest'
      ]) {
        expect(text, isNot(contains(syncWord)));
      }
    }
    expect(utf8.decode(exportJson), contains('${_markerPrefix}0'));
  });

  test(
      'acceptance 2: the database dump holds no private key or epoch key bytes',
      () async {
    final dump = await _databaseDump(deviceA.database.db);
    expect(dump.length, greaterThan(0));
    expect(_findLeaks(dump, secrets), isEmpty);
    expect(
        _findLeaks(await _databaseDump(deviceB.database.db), secrets), isEmpty);
  });

  test(
      'acceptance 2 and 4: the log capture holds no key bytes and no seeded marker',
      () {
    final log = Uint8List.fromList(utf8.encode(logLines.join('\n')));
    expect(_findLeaks(log, secrets), isEmpty);
    expect(logLines.join('\n'), isNot(contains(_markerPrefix)));
  });

  test(
      'acceptance 3: importing the backup export into a fresh device creates no members and sync is refused',
      () async {
    final fresh = await SecurityDevice.open('Fresh', root);
    await _SettingsHandlers.over(fresh.database.db)
        .import
        .call(ImportDataCommand(exportBackup, ImportStrategy.merge));
    final view = await fresh.service.currentView();

    expect(view.isPaired, isFalse);
    expect(fresh.membership.hasGroup, isFalse);
    expect(view.activeMembers.length, lessThanOrEqualTo(1));
    expect(await handshakeRefused(fresh, deviceA), isTrue);
    await fresh.close();
  });

  test(
      'acceptance 5: a merge import on one device appears on the other after one session',
      () async {
    final backup = await CompressionService().createWhphFile(jsonEncode({
      'appInfo': {'version': AppInfo.version},
      'notes': [
        {
          'id': _importedNoteId,
          'createdDate': '2026-01-01T00:00:00.000Z',
          'modifiedDate': null,
          'deletedDate': null,
          'title': _importedTitle,
          'content': '',
          'tags': []
        },
      ],
    }));
    final membersBefore =
        (await deviceA.service.currentView()).activeMembers.length;

    await _SettingsHandlers.over(deviceA.database.db)
        .import
        .call(ImportDataCommand(backup, ImportStrategy.merge));
    await syncDevices(deviceA, deviceB);

    expect(
        await deviceB.database.count(
            "SELECT COUNT(*) FROM note_table WHERE title = '$_importedTitle'"),
        1);
    expect((await deviceA.service.currentView()).activeMembers.length,
        membersBefore);
  });
}

class _Secret {
  final String label;
  final List<Uint8List> needles;
  _Secret._(this.label, this.needles);

  /// Raw bytes plus their hex and base64 spellings.
  factory _Secret.bytes(String label, Uint8List value) {
    final hex = value.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final base64 = base64Encode(value);
    final spellings = {
      hex,
      hex.toUpperCase(),
      base64,
      base64.replaceAll('=', ''),
      base64Url.encode(value),
      base64Url.encode(value).replaceAll('=', ''),
    };
    return _Secret._(label,
        [value, ...spellings.map((s) => Uint8List.fromList(utf8.encode(s)))]);
  }

  factory _Secret.text(String label, String value) =>
      _Secret._(label, [Uint8List.fromList(utf8.encode(value))]);
}

Future<List<_Secret>> _keySecrets(SecurityDevice device) async {
  final snapshot = (await device.keyStore.readKeyFile())!.snapshot;
  return [
    _Secret.bytes('${device.name} identity key', snapshot.x25519Private),
    _Secret.bytes('${device.name} signing seed', snapshot.ed25519Seed),
    for (final entry in snapshot.epochKeys.entries)
      _Secret.bytes('${device.name} epoch key ${entry.key}', entry.value),
  ];
}

Uint8List _filled(int length, int seed) => Uint8List.fromList(
    List.generate(length, (i) => (seed * 37 + i * 11) % 256));

Uint8List _asBytes(Object content) => content is Uint8List
    ? content
    : Uint8List.fromList(utf8.encode(content as String));

/// Labels of the secrets with a spelling found in [haystack].
List<String> _findLeaks(Uint8List haystack, List<_Secret> secrets) {
  final text = latin1.decode(haystack);
  return [
    for (final secret in secrets)
      if (secret.needles.any((needle) => text.contains(latin1.decode(needle))))
        secret.label,
  ];
}

/// Every cell of every table, text as UTF-8 and blobs as raw bytes.
Future<Uint8List> _databaseDump(AppDatabase db) async {
  final out = BytesBuilder();
  final tables = await db
      .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'")
      .get();
  for (final table in tables) {
    final name = table.read<String>('name');
    out.add(utf8.encode(name));
    for (final row in await db.customSelect('SELECT * FROM "$name"').get()) {
      for (final cell in row.data.values) {
        out.add(cell is Uint8List ? cell : utf8.encode('$cell'));
        out.addByte(0);
      }
    }
  }
  return out.takeBytes();
}

/// Export and import handlers over [db]: real note repositories, mocks for
/// everything else.
class _SettingsHandlers {
  final ExportDataCommandHandler export;
  final ImportDataCommandHandler import;
  _SettingsHandlers._(this.export, this.import);

  factory _SettingsHandlers.over(AppDatabase db) {
    AppDatabase.setInstanceForTesting(db);
    final noteRepository = DriftNoteRepository.withDatabase(db);
    final noteTagRepository = DriftNoteTagRepository.withDatabase(db);
    final appUsage = MockIAppUsageRepository();
    final appUsageTag = MockIAppUsageTagRepository();
    final appUsageTime = MockIAppUsageTimeRecordRepository();
    final appUsageRule = MockIAppUsageTagRuleRepository();
    final habit = MockIHabitRepository();
    final habitRecord = MockIHabitRecordRepository();
    final habitTag = MockIHabitTagsRepository();
    final tag = MockITagRepository();
    final tagTag = MockITagTagRepository();
    final task = MockITaskRepository();
    final taskTag = MockITaskTagRepository();
    final taskTime = MockITaskTimeRecordRepository();
    final setting = MockISettingRepository();
    final syncDevice = MockISyncDeviceRepository();
    final ignoreRule = MockIAppUsageIgnoreRuleRepository();
    for (final dynamic repository in [
      appUsage, appUsageTag, appUsageTime, appUsageRule, habit, habitRecord,
      habitTag, tag, tagTag, task, taskTag, //
      taskTime, setting, syncDevice, ignoreRule,
    ]) {
      when(repository.getAll(
              customWhereFilter: anyNamed('customWhereFilter'),
              customOrder: anyNamed('customOrder')))
          .thenAnswer((_) async => <Never>[]);
      when(repository.truncate()).thenAnswer((_) async {});
    }
    when(habit.updateMultiple(any)).thenAnswer((_) async {});
    when(task.updateMultiple(any)).thenAnswer((_) async {});
    final migration = MockIImportDataMigrationService();
    when(migration.isMigrationNeeded(any)).thenReturn(false);
    final mediator = Mediator(Pipeline())
      ..registerHandler<NormalizeHabitOrdersCommand,
          NormalizeHabitOrdersResponse, NormalizeHabitOrdersCommandHandler>(
        () => NormalizeHabitOrdersCommandHandler(habit),
      )
      ..registerHandler<NormalizeTaskOrdersCommand, NormalizeTaskOrdersResponse,
          NormalizeTaskOrdersCommandHandler>(
        () => NormalizeTaskOrdersCommandHandler(task),
      )
      ..registerHandler<NormalizeNoteOrdersCommand, NormalizeNoteOrdersResponse,
          NormalizeNoteOrdersCommandHandler>(
        () => NormalizeNoteOrdersCommandHandler(noteRepository),
      );
    final compression = CompressionService();
    return _SettingsHandlers._(
      ExportDataCommandHandler(
        appUsageRepository: appUsage,
        appUsageTagRepository: appUsageTag,
        appUsageTimeRecordRepository: appUsageTime,
        appUsageTagRuleRepository: appUsageRule,
        habitRepository: habit,
        habitRecordRepository: habitRecord,
        habitTagRepository: habitTag,
        tagRepository: tag,
        tagTagRepository: tagTag,
        taskRepository: task,
        taskTagRepository: taskTag,
        taskTimeRecordRepository: taskTime,
        settingRepository: setting,
        appUsageIgnoreRuleRepository: ignoreRule,
        noteRepository: noteRepository,
        noteTagRepository: noteTagRepository,
        compressionService: compression,
      ),
      ImportDataCommandHandler(
        appUsageRepository: appUsage,
        appUsageTagRepository: appUsageTag,
        appUsageTimeRecordRepository: appUsageTime,
        appUsageTagRuleRepository: appUsageRule,
        habitRepository: habit,
        habitRecordRepository: habitRecord,
        habitTagRepository: habitTag,
        tagRepository: tag,
        tagTagRepository: tagTag,
        taskRepository: task,
        taskTagRepository: taskTag,
        taskTimeRecordRepository: taskTime,
        settingRepository: setting,
        syncDeviceRepository: syncDevice,
        appUsageIgnoreRuleRepository: ignoreRule,
        noteRepository: noteRepository,
        noteTagRepository: noteTagRepository,
        migrationService: migration,
        compressionService: compression,
        mediator: mediator,
      ),
    );
  }
}
