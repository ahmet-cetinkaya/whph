import 'package:acore/acore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/habits/commands/update_habit_order_command.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/domain/features/habits/habit.dart';

/// Minimal in-memory habit store that mimics the two repository behaviours the
/// reorder handler depends on: fetch-by-id, and an order-sorted sibling list
/// using the same BINARY-collation semantics as SQLite (Dart's compareTo over
/// the ASCII base-62 rank alphabet).
class _InMemoryHabitRepository implements IHabitRepository {
  _InMemoryHabitRepository(this.habits);

  final List<Habit> habits;

  @override
  Future<Habit?> getById(String id, {bool includeDeleted = false}) async {
    for (final habit in habits) {
      if (habit.id == id) return habit;
    }
    return null;
  }

  @override
  Future<List<Habit>> getAll({
    CustomWhereFilter? customWhereFilter,
    List<CustomOrder>? customOrder,
    bool includeDeleted = false,
  }) async {
    // The handler always excludes the moved habit via customWhereFilter; the
    // excluded id is the sole variable it passes.
    final excludedId = customWhereFilter?.variables.first as String?;
    final result = habits.where((h) => h.id != excludedId && h.deletedDate == null).toList();
    result.sort((a, b) => a.order.compareTo(b.order));
    return result;
  }

  @override
  Future<void> update(Habit item) async {
    // Entity instances are shared, so the mutation is already visible; this
    // mirrors the real repository's write without doing extra work.
  }

  @override
  Future<void> updateMultiple(List<Habit> items) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Habit _habit(String id, String order) => Habit(
      id: id,
      createdDate: DateTime(2024),
      name: id,
      description: '',
      order: order,
    );

/// The visible order the user sees: exactly what the query returns for a
/// custom-sorted list (order, then created_date, then id).
List<String> visibleOrder(List<Habit> habits) {
  final sorted = List<Habit>.from(habits)..sort((a, b) => a.order.compareTo(b.order));
  return sorted.map((h) => h.id).toList();
}

/// Replays what the list widget does for a drop: given the currently visible
/// order, move [movedId] to [targetIndex] and derive the neighbor hints the
/// same way the UI does, then run the real handler.
Future<void> drop(
  UpdateHabitOrderCommandHandler handler,
  List<Habit> habits,
  String movedId,
  int targetIndex,
) async {
  final visible = visibleOrder(habits);
  final reduced = List<String>.from(visible)..remove(movedId);
  final clamped = targetIndex.clamp(0, reduced.length);

  await handler(UpdateHabitOrderCommand(
    habitId: movedId,
    targetIndex: clamped,
    beforeHabitId: clamped > 0 ? reduced[clamped - 1] : null,
    afterHabitId: clamped < reduced.length ? reduced[clamped] : null,
  ));
}

void main() {
  late List<Habit> habits;
  late UpdateHabitOrderCommandHandler handler;

  setUp(() {
    // Four habits, matching the reported today-page setup.
    habits = [
      _habit('a', 'F'),
      _habit('b', 'K'),
      _habit('c', 'P'),
      _habit('d', 'U'),
    ];
    handler = UpdateHabitOrderCommandHandler(_InMemoryHabitRepository(habits));
  });

  test('a single drop lands exactly where it was dropped', () async {
    await drop(handler, habits, 'a', 2);
    expect(visibleOrder(habits), ['b', 'c', 'a', 'd']);
  });

  test('repeated reorders stay consistent', () async {
    // Each drop states the intended resulting position, and the visible
    // order must match it every time — this is what "tutarsız kayıt"
    // (inconsistent persistence) would break.
    await drop(handler, habits, 'd', 0);
    expect(visibleOrder(habits), ['d', 'a', 'b', 'c']);

    await drop(handler, habits, 'a', 3);
    expect(visibleOrder(habits), ['d', 'b', 'c', 'a']);

    await drop(handler, habits, 'c', 0);
    expect(visibleOrder(habits), ['c', 'd', 'b', 'a']);

    await drop(handler, habits, 'b', 1);
    expect(visibleOrder(habits), ['c', 'b', 'd', 'a']);
  });

  test('every drop position in a 4-item list persists faithfully', () async {
    for (var target = 0; target < 4; target++) {
      habits = [
        _habit('a', 'F'),
        _habit('b', 'K'),
        _habit('c', 'P'),
        _habit('d', 'U'),
      ];
      handler = UpdateHabitOrderCommandHandler(_InMemoryHabitRepository(habits));

      await drop(handler, habits, 'a', target);

      final expected = ['b', 'c', 'd']..insert(target, 'a');
      expect(visibleOrder(habits), expected, reason: 'dropping "a" at index $target');
    }
  });
}
