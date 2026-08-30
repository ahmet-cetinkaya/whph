import 'package:acore/acore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/notes/note.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_status.dart';

void main() {
  final createdDate = DateTime.utc(2026, 1, 1).toIso8601String();

  Map<String, dynamic> habitJson(Object? order) => {
        'id': 'habit',
        'createdDate': createdDate,
        'name': 'Habit',
        'description': '',
        'order': order,
      };

  Map<String, dynamic> taskJson(Object? order) => {
        'id': 'task',
        'createdDate': createdDate,
        'title': 'Task',
        'order': order,
      };

  Map<String, dynamic> taskStatusJson(Object? order) => {
        'id': 'status',
        'createdDate': createdDate,
        'name': 'Status',
        'order': order,
      };

  Map<String, dynamic> noteJson(Object? order) => {
        'id': 'note',
        'createdDate': createdDate,
        'title': 'Note',
        'order': order,
      };

  test('converts numeric legacy orders for every ordered entity', () {
    final expected = OrderRank.fromLegacyDouble(1000.0);

    expect(Habit.fromJson(habitJson(1000.0)).order, expected);
    expect(Task.fromJson(taskJson(1000.0)).order, expected);
    expect(TaskStatus.fromJson(taskStatusJson(1000.0)).order, expected);
    expect(Note.fromJson(noteJson(1000.0)).order, expected);
  });

  test('falls back for null and map orders without throwing', () {
    expect(Habit.fromJson(habitJson(null)).order, OrderRank.initialRank);
    expect(Task.fromJson(taskJson(<String, String>{})).order, OrderRank.initialRank);
    expect(TaskStatus.fromJson(taskStatusJson(null)).order, OrderRank.initialRank);
    expect(Note.fromJson(noteJson(<String, String>{})).order, OrderRank.initialRank);
  });

  test('falls back for malformed rank strings', () {
    expect(Habit.fromJson(habitJson('invalid rank')).order, OrderRank.initialRank);
    expect(Task.fromJson(taskJson('0')).order, OrderRank.initialRank);
    expect(TaskStatus.fromJson(taskStatusJson('V0')).order, OrderRank.initialRank);
    expect(Note.fromJson(noteJson('!')).order, OrderRank.initialRank);
  });

  test('preserves canonical rank strings through JSON round trips', () {
    const order = 'V';
    final created = DateTime.utc(2026, 1, 1);

    final habit = Habit(
      id: 'habit',
      createdDate: created,
      name: 'Habit',
      description: '',
      order: order,
    );
    final task = Task(id: 'task', createdDate: created, title: 'Task', order: order);
    final taskStatus = TaskStatus(id: 'status', createdDate: created, name: 'Status', order: order);
    final note = Note(id: 'note', createdDate: created, title: 'Note', order: order);

    expect(Habit.fromJson(habit.toJson()).order, order);
    expect(Task.fromJson(task.toJson()).order, order);
    expect(TaskStatus.fromJson(taskStatus.toJson()).order, order);
    expect(Note.fromJson(note.toJson()).order, order);
  });
}
