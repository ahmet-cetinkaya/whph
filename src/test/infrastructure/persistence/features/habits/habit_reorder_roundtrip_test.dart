import 'dart:io';

import 'package:acore/acore.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/habits/commands/normalize_habit_orders_command.dart';
import 'package:whph/core/application/features/habits/commands/update_habit_order_command.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habits_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

/// Exercises the full reorder loop against a real SQLite database: the
/// handler's sibling fetch, the rank it persists, and the read path the list
/// actually renders from. Fakes cannot catch a disagreement between those
/// three, since each uses its own SQL builder.
void main() {
  late AppDatabase database;
  late Directory tempDir;
  late DriftHabitRepository repository;
  late NormalizeHabitOrdersCommandHandler normalizeHandler;
  late UpdateHabitOrderCommandHandler handler;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tempDir = await Directory.systemTemp.createTemp();
    AppDatabase.testDirectory = tempDir;
    AppDatabase.isTestMode = true;
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftHabitRepository.withDatabase(database);
    normalizeHandler = NormalizeHabitOrdersCommandHandler(repository);
    handler = UpdateHabitOrderCommandHandler(repository);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seed(List<(String, String)> idsAndOrders) async {
    for (final (index, pair) in idsAndOrders.indexed) {
      await repository.add(Habit(
        id: pair.$1,
        // Distinct creation timestamps so the created_date tie-breaker is
        // deterministic rather than incidental.
        createdDate: DateTime.utc(2024, 1, 1).add(Duration(minutes: index)),
        name: pair.$1,
        description: '',
        order: pair.$2,
      ));
    }
  }

  /// The order the today page actually renders: the query's custom-sort
  /// ordering (order, created_date, id).
  Future<List<String>> visibleOrder() async {
    final page = await repository.getHabitListItems(
      0,
      100,
      customOrder: [
        CustomOrder(field: 'order', direction: SortDirection.asc),
        CustomOrder(field: 'created_date', direction: SortDirection.asc),
        CustomOrder(field: 'id', direction: SortDirection.asc),
      ],
    );
    return page.items.map((h) => h.id).toList();
  }

  /// Replays a drop the way the list widget does: derive neighbor hints from
  /// the currently visible order, then invoke the real handler.
  Future<void> drop(String movedId, int targetIndex) async {
    final visible = await visibleOrder();
    final reduced = List<String>.from(visible)..remove(movedId);
    final clamped = targetIndex.clamp(0, reduced.length);

    await handler(UpdateHabitOrderCommand(
      habitId: movedId,
      targetIndex: clamped,
      beforeHabitId: clamped > 0 ? reduced[clamped - 1] : null,
      afterHabitId: clamped < reduced.length ? reduced[clamped] : null,
    ));
  }

  test('a single drop persists exactly where it was dropped', () async {
    await seed([('a', 'F'), ('b', 'K'), ('c', 'P'), ('d', 'U')]);

    await drop('a', 2);

    expect(await visibleOrder(), ['b', 'c', 'a', 'd']);
  });

  test('repeated reorders stay consistent across the real read path', () async {
    await seed([('a', 'F'), ('b', 'K'), ('c', 'P'), ('d', 'U')]);

    await drop('d', 0);
    expect(await visibleOrder(), ['d', 'a', 'b', 'c']);

    await drop('a', 3);
    expect(await visibleOrder(), ['d', 'b', 'c', 'a']);

    await drop('c', 0);
    expect(await visibleOrder(), ['c', 'd', 'b', 'a']);

    await drop('b', 1);
    expect(await visibleOrder(), ['c', 'b', 'd', 'a']);
  });

  test('every drop position in a 4-habit list persists faithfully', () async {
    for (var target = 0; target < 4; target++) {
      await database.close();
      database = AppDatabase(NativeDatabase.memory());
      repository = DriftHabitRepository.withDatabase(database);
      handler = UpdateHabitOrderCommandHandler(repository);

      await seed([('a', 'F'), ('b', 'K'), ('c', 'P'), ('d', 'U')]);
      await drop('a', target);

      final expected = ['b', 'c', 'd']..insert(target, 'a');
      expect(await visibleOrder(), expected, reason: 'dropping "a" at index $target');
    }
  });

  test('habits seeded at the canonical default rank still reorder', () async {
    // Fresh installs and the v36 migration can leave every habit sharing the
    // canonical initial rank, so the very first drag must renormalize rather
    // than silently no-op.
    await seed([('a', 'U'), ('b', 'U'), ('c', 'U'), ('d', 'U')]);

    final before = await visibleOrder();
    await drop(before.last, 0);

    final after = await visibleOrder();
    expect(after.first, before.last);
    expect(after.toSet(), before.toSet());
  });

  test('an interior drop preserves the visible order when default ranks are tied', () async {
    // Insert rows in an order that deliberately disagrees with the Today
    // query's created_date tie-breaker. An order-only sibling fetch must not
    // use this physical row order when it renormalizes tied ranks.
    for (final habit in [
      Habit(id: 'd', createdDate: DateTime.utc(2024, 1, 4), name: 'd', description: '', order: 'U'),
      Habit(id: 'b', createdDate: DateTime.utc(2024, 1, 2), name: 'b', description: '', order: 'U'),
      Habit(id: 'a', createdDate: DateTime.utc(2024, 1, 1), name: 'a', description: '', order: 'U'),
      Habit(id: 'c', createdDate: DateTime.utc(2024, 1, 3), name: 'c', description: '', order: 'U'),
    ]) {
      await repository.add(habit);
    }

    expect(await visibleOrder(), ['a', 'b', 'c', 'd']);

    await drop('a', 1);

    expect(
      await visibleOrder(),
      ['b', 'a', 'c', 'd'],
      reason: 'persistence must use the same tie-breakers as the visible Today list',
    );
  });

  test('normalizing tied default ranks preserves the visible order', () async {
    for (final habit in [
      Habit(id: 'd', createdDate: DateTime.utc(2024, 1, 4), name: 'd', description: '', order: 'U'),
      Habit(id: 'b', createdDate: DateTime.utc(2024, 1, 2), name: 'b', description: '', order: 'U'),
      Habit(id: 'a', createdDate: DateTime.utc(2024, 1, 1), name: 'a', description: '', order: 'U'),
      Habit(id: 'c', createdDate: DateTime.utc(2024, 1, 3), name: 'c', description: '', order: 'U'),
    ]) {
      await repository.add(habit);
    }

    expect(await visibleOrder(), ['a', 'b', 'c', 'd']);

    await normalizeHandler(const NormalizeHabitOrdersCommand());

    expect(
      await visibleOrder(),
      ['a', 'b', 'c', 'd'],
      reason: 'automatic normalization must preserve the visible tie-break order',
    );
  });

  test('reordering a visible habit does not disturb ranks of hidden ones', () async {
    // The today page shows a page of 5 while more habits exist in the
    // database. The handler reorders against ALL habits, but the UI derives
    // neighbor hints only from what is visible, so a drop must still land
    // correctly relative to the visible set.
    await seed([
      ('a', 'F'),
      ('b', 'K'),
      ('c', 'P'),
      ('d', 'U'),
      ('e', 'Z'),
      ('f', 'd'),
      ('g', 'i'),
    ]);

    final full = await visibleOrder();
    expect(full, ['a', 'b', 'c', 'd', 'e', 'f', 'g']);

    // Move the first habit to sit between 'c' and 'd'.
    await drop('a', 3);

    expect(await visibleOrder(), ['b', 'c', 'd', 'a', 'e', 'f', 'g']);
  });

  test('archived habits do not break the visible drop position', () async {
    // The today page does not filter archived habits out of the query, so
    // they participate in the sibling set the handler reorders against.
    await seed([('a', 'F'), ('b', 'K'), ('c', 'P'), ('d', 'U')]);
    final archived = await repository.getById('b');
    archived!.archivedDate = DateTime.utc(2024, 6, 1);
    await repository.update(archived);

    await drop('a', 2);

    expect(await visibleOrder(), ['b', 'c', 'a', 'd']);
  });
}
