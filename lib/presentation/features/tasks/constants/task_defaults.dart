import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/acore/repository/models/sort_direction.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/models/sort_config.dart';
import 'package:whph/presentation/shared/models/sort_option_with_translation_key.dart';

class TaskDefaults {
  static const SortConfig<TaskSortFields> sorting = SortConfig<TaskSortFields>(
    orderOptions: [
      SortOptionWithTranslationKey(
        field: TaskSortFields.priority,
        direction: SortDirection.desc,
        translationKey: TaskTranslationKeys.priorityLabel,
      ),
      SortOptionWithTranslationKey(
        field: TaskSortFields.plannedDate,
        direction: SortDirection.asc,
        translationKey: TaskTranslationKeys.plannedDateLabel,
      ),
    ],
    useCustomOrder: false,
  );
}
