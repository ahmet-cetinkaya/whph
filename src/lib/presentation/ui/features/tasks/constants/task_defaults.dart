import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_view_mode.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';

class TaskDefaults {
  static const SortConfig<TaskSortFields> sorting = SortConfig<TaskSortFields>(
    orderOptions: [
      SortOptionWithTranslationKey(
        field: TaskSortFields.plannedDate,
        direction: SortDirection.asc,
        translationKey: TaskTranslationKeys.plannedDateLabel,
      ),
      SortOptionWithTranslationKey(
        field: TaskSortFields.deadlineDate,
        direction: SortDirection.asc,
        translationKey: TaskTranslationKeys.deadlineDateLabel,
      ),
      SortOptionWithTranslationKey(
        field: TaskSortFields.priority,
        direction: SortDirection.desc,
        translationKey: TaskTranslationKeys.priorityLabel,
      ),
    ],
    useCustomOrder: false,
    enableGrouping: false,
  );

  static const SortConfig<TaskSortFields> boardSorting = SortConfig<TaskSortFields>(
    orderOptions: [
      SortOptionWithTranslationKey(
        field: TaskSortFields.status,
        direction: SortDirection.asc,
        translationKey: TaskTranslationKeys.statusLabel,
      ),
    ],
    useCustomOrder: false,
    enableGrouping: true,
    groupOption: SortOptionWithTranslationKey(
      field: TaskSortFields.status,
      direction: SortDirection.asc,
      translationKey: TaskTranslationKeys.statusLabel,
    ),
  );

  /// The sort configuration a view mode must run with.
  ///
  /// Board is grouped by status *by definition*, so entering it forces status
  /// grouping unconditionally — an existing non-status grouping must not survive.
  /// Entering board must also not silently switch the user's custom sort off:
  /// rank orders the cards within each column, so it is carried forward.
  /// List and calendar keep whatever the user configured.
  static SortConfig<TaskSortFields> sortConfigForViewMode(
    TaskViewMode mode,
    SortConfig<TaskSortFields> current,
  ) =>
      mode == TaskViewMode.board ? boardSorting.copyWith(useCustomOrder: current.useCustomOrder) : current;
}
