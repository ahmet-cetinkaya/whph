import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/habits/models/habit_sort_fields.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/utils/habit_grouping_helper.dart';
import 'package:whph/core/application/shared/constants/shared_translation_keys.dart';

void main() {
  group('HabitGroupingHelper', () {
    test('getGroupName returns null when sortField is null', () {
      final habit = HabitListItem(id: '1', name: 'Habit');
      final result = HabitGroupingHelper.getGroupName(habit, null);
      expect(result, isNull);
    });

    test('getGroupName groups by Name (First Letter)', () {
      final habitA = HabitListItem(id: '1', name: 'Apple');
      final habitB = HabitListItem(id: '2', name: 'Banana');
      final habitLowerA = HabitListItem(id: '3', name: 'apple');
      final habitSymbol = HabitListItem(id: '4', name: '@Task');
      final habitEmpty = HabitListItem(id: '5', name: '');

      expect(HabitGroupingHelper.getGroupName(habitA, HabitSortFields.name), 'A');
      expect(HabitGroupingHelper.getGroupName(habitB, HabitSortFields.name), 'B');
      expect(HabitGroupingHelper.getGroupName(habitLowerA, HabitSortFields.name), 'A');
      expect(HabitGroupingHelper.getGroupName(habitSymbol, HabitSortFields.name), '#');
      expect(HabitGroupingHelper.getGroupName(habitEmpty, HabitSortFields.name), '#');
    });

    test('getGroupName groups by Estimated Time', () {
      final habitShort = HabitListItem(id: '1', name: 'Short', estimatedTime: 10);
      final habitMedium = HabitListItem(id: '2', name: 'Medium', estimatedTime: 45);
      final habitLong = HabitListItem(id: '3', name: 'Long', estimatedTime: 130);
      final habitNone = HabitListItem(id: '4', name: 'None');

      expect(HabitGroupingHelper.getGroupName(habitShort, HabitSortFields.estimatedTime),
          SharedTranslationKeys.durationLessThan15Min);
      expect(HabitGroupingHelper.getGroupName(habitMedium, HabitSortFields.estimatedTime),
          SharedTranslationKeys.duration30To60Min);
      expect(HabitGroupingHelper.getGroupName(habitLong, HabitSortFields.estimatedTime),
          SharedTranslationKeys.durationMoreThan2Hours);
      expect(HabitGroupingHelper.getGroupName(habitNone, HabitSortFields.estimatedTime), SharedTranslationKeys.none);
    });

    test('getGroupName groups by Actual Time', () {
      final habitShort = HabitListItem(id: '1', name: 'Short', actualTime: 10);

      expect(HabitGroupingHelper.getGroupName(habitShort, HabitSortFields.actualTime),
          SharedTranslationKeys.durationLessThan15Min);
    });
  });
}
