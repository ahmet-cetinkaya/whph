import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_view_mode.dart';

void main() {
  group('TaskViewMode.fromName', () {
    test('returns the matching mode for a valid name', () {
      expect(TaskViewModeParse.fromName('list'), TaskViewMode.list);
      expect(TaskViewModeParse.fromName('board'), TaskViewMode.board);
    });

    test('falls back to list for null', () {
      expect(TaskViewModeParse.fromName(null), TaskViewMode.list);
    });

    test('falls back to list for an unknown name', () {
      expect(TaskViewModeParse.fromName('grid'), TaskViewMode.list);
      expect(TaskViewModeParse.fromName(''), TaskViewMode.list);
      expect(TaskViewModeParse.fromName('BOARD'), TaskViewMode.list);
    });

    test('round-trips via enum.name', () {
      for (final mode in TaskViewMode.values) {
        expect(TaskViewModeParse.fromName(mode.name), mode);
      }
    });
  });
}
