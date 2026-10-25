// The synthetic schema-v37 duplicates fixtures, opened through the real
// v37 -> v38 migration, for the identity-rule upgrade scenarios (T27 part 1).
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/application/shared/services/mcp_restore_barrier.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

import '../../../fixtures/sync/fixture_builder.dart';

const int _migratedSchemaVersion = 38;

class _MigratingAppDatabase extends AppDatabase {
  _MigratingAppDatabase(QueryExecutor executor) : super.withRestoreBarrier(executor, McpRestoreBarrier());

  @override
  int get schemaVersion => _migratedSchemaVersion;
}

/// One duplicate group of the fixture manifest.
class DuplicateGroup {
  final String rule;
  final String table;
  final String key;
  final List<String> ids;
  final List<String> liveIds;
  final List<Map<String, Object?>> dependents;

  DuplicateGroup(Map<String, Object?> json)
      : rule = json['rule']! as String,
        table = json['table']! as String,
        key = json['key']! as String,
        ids = (json['ids']! as List).cast<String>(),
        liveIds = (json['liveIds']! as List).cast<String>(),
        dependents = [for (final d in (json['dependents'] as List? ?? const [])) (d as Map).cast<String, Object?>()];

  /// Live dependents in [dependentTable].
  List<String> liveDependentIds(String dependentTable) => [
        for (final d in dependents)
          if (d['table'] == dependentTable && d['live'] == true) d['id']! as String,
      ];
}

class UpgradeFixtures {
  final Directory root;
  final String fixtureName;
  final File _pristine;
  final List<AppDatabase> _opened = [];
  var _copies = 0;

  UpgradeFixtures._(this.root, this.fixtureName, this._pristine);

  static Future<UpgradeFixtures> build(String fixtureName) async {
    final root = Directory.systemTemp.createTempSync('whph_t27_upgrade_');
    AppDatabase.testDirectory = root;
    AppDatabase.isTestMode = true;
    final out = Directory(p.join(root.path, 'fixtures'));
    await buildFixture(fixtureName, seed: defaultFixtureSeed, out: out);
    return UpgradeFixtures._(root, fixtureName, File(fixtureDatabasePath(out, fixtureName)));
  }

  List<DuplicateGroup> get groups {
    final manifest = File(p.join(p.dirname(_pristine.path), '$fixtureName.manifest.json'));
    final json = jsonDecode(manifest.readAsStringSync()) as Map<String, Object?>;
    return [for (final g in json['duplicateGroups']! as List) DuplicateGroup((g as Map).cast<String, Object?>())];
  }

  /// A fresh copy of the v37 fixture; the v38 migration runs on open.
  Future<AppDatabase> openUpgraded() async {
    final copy = _pristine.copySync(p.join(root.path, 'copy-${_copies++}.sqlite'));
    final db = _MigratingAppDatabase(NativeDatabase(copy));
    _opened.add(db);
    await db.customSelect('SELECT 1').get();
    return db;
  }

  Future<void> close() async {
    for (final db in _opened) {
      await db.close();
    }
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

Future<List<Map<String, Object?>>> selectRows(AppDatabase db, String sql, [List<Object?> args = const []]) async =>
    (await db.customSelect(sql, variables: [for (final a in args) Variable<Object>(a)]).get())
        .map((row) => row.data)
        .toList();

Future<int> selectCount(AppDatabase db, String sql, [List<Object?> args = const []]) async =>
    (await selectRows(db, sql, args)).single.values.first! as int;
