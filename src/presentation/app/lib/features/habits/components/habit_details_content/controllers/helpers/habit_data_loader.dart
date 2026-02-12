import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:application/features/habits/queries/get_habit_query.dart';
import 'package:application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:application/features/habits/queries/get_list_habit_tags_query.dart';
import 'package:application/features/habits/queries/get_total_duration_by_habit_id_query.dart';
import 'package:whph/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/utils/async_error_handler.dart';

/// Handles data loading operations for habit details.
class HabitDataLoader {
  final Mediator _mediator;
  final ITranslationService _translationService;

  HabitDataLoader({
    required Mediator mediator,
    required ITranslationService translationService,
  })  : _mediator = mediator,
        _translationService = translationService;

  /// Loads the habit details.
  Future<GetHabitQueryResponse?> loadHabit(String habitId, BuildContext context) async {
    return await AsyncErrorHandler.execute<GetHabitQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.loadingDetailsError),
      operation: () async {
        final query = GetHabitQuery(id: habitId);
        return await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(query);
      },
    );
  }

  /// Loads habit records for a specific month.
  Future<GetListHabitRecordsQueryResponse?> loadHabitRecordsForMonth(
    DateTime month,
    String habitId,
    BuildContext context,
  ) async {
    return await AsyncErrorHandler.execute<GetListHabitRecordsQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.loadingRecordsError),
      operation: () async {
        final firstDayOfMonth = DateTime(month.year, month.month, 1);
        final firstWeekdayOfMonth = firstDayOfMonth.weekday;
        final previousMonthDays = firstWeekdayOfMonth - 1;
        final firstDisplayedDate = firstDayOfMonth.subtract(Duration(days: previousMonthDays));

        final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
        final lastWeekdayOfMonth = lastDayOfMonth.weekday;
        final nextMonthDays = 7 - lastWeekdayOfMonth;
        final lastDisplayedDate = lastDayOfMonth.add(Duration(days: nextMonthDays));

        final query = GetListHabitRecordsQuery(
          pageIndex: 0,
          pageSize: 50,
          habitId: habitId,
          startDate: firstDisplayedDate.toUtc(),
          endDate: lastDisplayedDate.toUtc(),
        );
        return await _mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(query);
      },
    );
  }

  /// Loads all habit tags with pagination.
  Future<GetListHabitTagsQueryResponse?> loadHabitTags(String habitId, BuildContext context) async {
    int pageIndex = 0;
    const int pageSize = 50;
    GetListHabitTagsQueryResponse? allTags;

    while (true) {
      final query = GetListHabitTagsQuery(habitId: habitId, pageIndex: pageIndex, pageSize: pageSize);
      final result = await AsyncErrorHandler.execute<GetListHabitTagsQueryResponse>(
        context: context,
        errorMessage: _translationService.translate(HabitTranslationKeys.loadingTagsError),
        operation: () async => await _mediator.send<GetListHabitTagsQuery, GetListHabitTagsQueryResponse>(query),
        onSuccess: (response) {
          if (allTags == null) {
            allTags = response;
          } else {
            allTags!.items.addAll(response.items);
          }
        },
      );

      if (result == null || result.items.isEmpty || result.items.length < pageSize) break;
      pageIndex++;
    }

    return allTags ?? GetListHabitTagsQueryResponse(items: [], pageIndex: 0, pageSize: 50, totalItemCount: 0);
  }

  /// Refreshes the total duration for a habit.
  Future<int> refreshTotalDuration(String habitId) async {
    try {
      final query = GetTotalDurationByHabitIdQuery(habitId: habitId);
      final result =
          await _mediator.send<GetTotalDurationByHabitIdQuery, GetTotalDurationByHabitIdQueryResponse>(query);
      return result.totalDuration;
    } catch (e) {
      return 0;
    }
  }
}
