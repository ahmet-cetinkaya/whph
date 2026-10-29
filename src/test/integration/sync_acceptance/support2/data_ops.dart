// SQL-level user actions on a lab device. Each helper writes the same columns
// the repositories write, so the capture triggers see what a real edit does.
import 'package:drift/drift.dart' show Variable;
import 'package:whph/core/application/shared/utils/sync_identity.dart';

import 'lab.dart';

const int _createdSeconds = 1700000000;
const int _markerTotal = 50;
const int _markerTasks = 20;
const int _markerNotes = 15;

Future<void> insertRow(LabDevice device, String table, Map<String, Object?> values) {
  final columns = {'created_date': _createdSeconds, ...values};
  final names = columns.keys.map((name) => '"$name"').join(', ');
  final marks = List.filled(columns.length, '?').join(', ');
  return device.db.sql('INSERT INTO "$table" ($names) VALUES ($marks)', columns.values.toList());
}

Future<void> updateRow(LabDevice device, String table, String id, Map<String, Object?> values) {
  final assignments = values.keys.map((name) => '"$name" = ?').join(', ');
  return device.db.sql('UPDATE "$table" SET $assignments WHERE id = ?', [...values.values, id]);
}

Future<void> softDeleteRow(LabDevice device, String table, String id, {int at = _createdSeconds + 10}) =>
    updateRow(device, table, id, {'deleted_date': at});

Future<Map<String, Object?>?> findRow(LabDevice device, String table, String id) async {
  final rows = await device.db.rows('SELECT * FROM "$table" WHERE id = ?', [Variable.withString(id)]);
  return rows.isEmpty ? null : rows.single;
}

Future<Object?> cellOf(LabDevice device, String table, String id, String column) async =>
    (await findRow(device, table, id))?[column];

Future<int> countRows(LabDevice device, String table, {bool liveOnly = false}) =>
    device.db.count('SELECT COUNT(*) FROM "$table"${liveOnly ? ' WHERE deleted_date IS NULL' : ''}');

/// Deterministic id of a join row, as the app derives it (FR-030).
String joinId(String kind, String left, String right) => syncIdentityId(kind, [left, right]);

Future<void> addNote(LabDevice device, String id, String title, {String content = 'body', String? order}) =>
    insertRow(device, 'note_table', {
      'id': id,
      'title': title,
      'content': content,
      if (order != null) 'order': order,
    });

Future<void> addTask(LabDevice device, String id, String title, {Map<String, Object?> extra = const {}}) =>
    insertRow(device, 'task_table', {'id': id, 'title': title, ...extra});

Future<void> addAppUsage(LabDevice device, String id, String name) =>
    insertRow(device, 'app_usage_table', {'id': id, 'name': name});

Future<void> addTag(LabDevice device, String id, String name) =>
    insertRow(device, 'tag_table', {'id': id, 'name': name});

Future<String> noteTitle(LabDevice device, String id) async => '${await cellOf(device, 'note_table', id, 'title')}';

Future<Set<String>> liveNoteIds(LabDevice device) async => {
      for (final row in await device.db.rows('SELECT id FROM note_table WHERE deleted_date IS NULL')) '${row['id']}',
    };

/// Writes the 50 SC-004 markers: 20 task titles, 15 note bodies, 15 app names.
Future<List<String>> seedFiftyMarkers(LabDevice device, {String prefix = 'T27MARK'}) async {
  final markers = <String>[];
  for (var index = 0; index < _markerTotal; index++) {
    final marker = '$prefix-${index.toString().padLeft(2, '0')}-confidential';
    markers.add(marker);
    if (index < _markerTasks) {
      await addTask(device, '$prefix-task-$index', marker);
    } else if (index < _markerTasks + _markerNotes) {
      await addNote(device, '$prefix-note-$index', 'note $index', content: marker);
    } else {
      await addAppUsage(device, '$prefix-app-$index', marker);
    }
  }
  return markers;
}
