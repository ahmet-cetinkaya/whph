import 'package:acore/acore.dart';
import 'package:whph/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/shared/models/sort_config.dart';
import 'package:application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/shared/models/sort_option_with_translation_key.dart';

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
}
