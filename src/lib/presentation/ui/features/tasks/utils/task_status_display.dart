import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Resolves a task status display name. Built-in statuses keep an empty stored
/// name and are localized at display time; once renamed they carry a literal
/// name that is shown verbatim.
class TaskStatusDisplay {
  static String resolveName(
    ITranslationService translationService, {
    required String id,
    required String name,
    required bool isDoneStatus,
  }) {
    if (name.isNotEmpty) return name;
    if (isDoneStatus || id == TaskStatusConstants.doneId) {
      return translationService.translate(TaskTranslationKeys.statusBuiltInDone);
    }
    return translationService.translate(TaskTranslationKeys.statusBuiltInTodo);
  }

  TaskStatusDisplay._();
}
