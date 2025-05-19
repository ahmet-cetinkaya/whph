import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/add_task_tag_command.dart';
import 'package:whph/application/features/tasks/commands/delete_task_command.dart';
import 'package:whph/application/features/tasks/commands/remove_task_tag_command.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/commands/save_task_time_record_command.dart';
import 'package:whph/application/features/tasks/commands/update_task_order_command.dart';
import 'package:whph/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/application/features/tasks/services/task_recurrence_service.dart';

void registerTasksFeature(
  IContainer container,
  Mediator mediator,
  ITaskRepository taskRepository,
  ITaskTagRepository taskTagRepository,
  ITaskTimeRecordRepository taskTimeRecordRepository,
  ITagRepository tagRepository,
) {
  // Register the task recurrence service
  container.registerSingleton<ITaskRecurrenceService>((_) => TaskRecurrenceService());

  mediator
    ..registerHandler<SaveTaskCommand, SaveTaskCommandResponse, SaveTaskCommandHandler>(
      () => SaveTaskCommandHandler(taskService: taskRepository, taskTagRepository: taskTagRepository),
    )
    ..registerHandler<DeleteTaskCommand, DeleteTaskCommandResponse, DeleteTaskCommandHandler>(
      () => DeleteTaskCommandHandler(taskRepository: taskRepository),
    )
    ..registerHandler<GetListTasksQuery, GetListTasksQueryResponse, GetListTasksQueryHandler>(
      () => GetListTasksQueryHandler(
        taskRepository: taskRepository,
        taskTagRepository: taskTagRepository,
        tagRepository: tagRepository,
      ),
    )
    ..registerHandler<GetTaskQuery, GetTaskQueryResponse, GetTaskQueryHandler>(
      () => GetTaskQueryHandler(
        taskRepository: taskRepository,
        taskTimeRecordRepository: taskTimeRecordRepository,
      ),
    )
    ..registerHandler<AddTaskTagCommand, AddTaskTagCommandResponse, AddTaskTagCommandHandler>(
      () => AddTaskTagCommandHandler(taskTagRepository: taskTagRepository),
    )
    ..registerHandler<RemoveTaskTagCommand, RemoveTaskTagCommandResponse, RemoveTaskTagCommandHandler>(
      () => RemoveTaskTagCommandHandler(taskTagRepository: taskTagRepository),
    )
    ..registerHandler<GetListTaskTagsQuery, GetListTaskTagsQueryResponse, GetListTaskTagsQueryHandler>(
      () => GetListTaskTagsQueryHandler(
        tagRepository: tagRepository,
        taskTagRepository: taskTagRepository,
      ),
    )
    ..registerHandler<SaveTaskTimeRecordCommand, SaveTaskTimeRecordCommandResponse, SaveTaskTimeRecordCommandHandler>(
      () => SaveTaskTimeRecordCommandHandler(taskTimeRecordRepository: taskTimeRecordRepository),
    )
    ..registerHandler<UpdateTaskOrderCommand, void, UpdateTaskOrderCommandHandler>(
      () => UpdateTaskOrderCommandHandler(taskRepository),
    );
}
