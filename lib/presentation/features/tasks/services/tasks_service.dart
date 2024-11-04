import 'package:flutter/foundation.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';

class TasksService {
  final ValueNotifier<SaveTaskCommandResponse?> onTaskSaved = ValueNotifier(null);
}
