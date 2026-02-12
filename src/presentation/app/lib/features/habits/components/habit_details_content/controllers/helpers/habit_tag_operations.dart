import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:application/features/habits/commands/add_habit_tag_command.dart';
import 'package:application/features/habits/commands/remove_habit_tag_command.dart';
import 'package:application/features/habits/commands/update_habit_tags_order_command.dart';
import 'package:application/features/habits/queries/get_list_habit_tags_query.dart';
import 'package:whph/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/features/habits/services/habits_service.dart';
import 'package:whph/shared/models/dropdown_option.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/utils/async_error_handler.dart';

/// Handles tag operations for habit details.
class HabitTagOperations {
  final Mediator _mediator;
  final ITranslationService _translationService;
  final HabitsService _habitsService;

  HabitTagOperations({
    required Mediator mediator,
    required ITranslationService translationService,
    required HabitsService habitsService,
  })  : _mediator = mediator,
        _translationService = translationService,
        _habitsService = habitsService;

  /// Adds a tag to the habit.
  Future<bool> addTag(String tagId, String habitId, BuildContext context) async {
    final result = await AsyncErrorHandler.execute<AddHabitTagCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.addingTagError),
      operation: () async {
        final command = AddHabitTagCommand(habitId: habitId, tagId: tagId);
        return await _mediator.send(command);
      },
    );
    return result != null;
  }

  /// Removes a tag from the habit.
  Future<bool> removeTag(String id, BuildContext context) async {
    final result = await AsyncErrorHandler.execute<RemoveHabitTagCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.removingTagError),
      operation: () async {
        final command = RemoveHabitTagCommand(id: id);
        return await _mediator.send(command);
      },
    );
    return result != null;
  }

  /// Processes tag changes by adding and removing tags as needed.
  Future<void> processTagChanges({
    required List<DropdownOption<String>> tagOptions,
    required String habitId,
    required BuildContext context,
    required GetListHabitTagsQueryResponse? currentTags,
    required Future<void> Function(String habitId, BuildContext context) reloadTags,
  }) async {
    if (currentTags == null) return;

    final tagsToAdd = tagOptions
        .where((tagOption) => !currentTags.items.any((habitTag) => habitTag.tagId == tagOption.value))
        .map((option) => option.value)
        .toList();

    final tagsToRemove =
        currentTags.items.where((habitTag) => !tagOptions.map((tag) => tag.value).contains(habitTag.tagId)).toList();

    for (final tagId in tagsToAdd) {
      if (!context.mounted) return;
      final success = await addTag(tagId, habitId, context);
      if (success && context.mounted) {
        await reloadTags(habitId, context);
      }
    }

    for (final habitTag in tagsToRemove) {
      if (!context.mounted) return;
      final success = await removeTag(habitTag.id, context);
      if (success && context.mounted) {
        await reloadTags(habitId, context);
      }
    }

    if (tagOptions.isNotEmpty) {
      final tagOrders = {for (int i = 0; i < tagOptions.length; i++) tagOptions[i].value: i};
      final orderCommand = UpdateHabitTagsOrderCommand(habitId: habitId, tagOrders: tagOrders);
      await _mediator.send(orderCommand);
      if (context.mounted) {
        await reloadTags(habitId, context);
      }
    }

    if (tagsToAdd.isNotEmpty || tagsToRemove.isNotEmpty || tagOptions.isNotEmpty) {
      _habitsService.notifyHabitUpdated(habitId);
    }
  }
}
