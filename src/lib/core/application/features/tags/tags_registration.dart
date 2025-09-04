import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/core/application/features/tags/commands/add_tag_tag_command.dart';
import 'package:whph/core/application/features/tags/commands/delete_tag_command.dart';
import 'package:whph/core/application/features/tags/commands/remove_tag_tag_command.dart';
import 'package:whph/core/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/core/application/features/tags/queries/get_elements_by_time_query.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tag_tags_query.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/application/features/tags/queries/get_tag_query.dart';
import 'package:whph/core/application/features/tags/queries/get_tag_times_data_query.dart';
import 'package:whph/core/application/features/tags/queries/get_top_tags_by_time_query.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_tag_repository.dart';
import 'package:acore/acore.dart';

void registerTagsFeature(
  IContainer container,
  Mediator mediator,
  ITagRepository tagRepository,
  ITagTagRepository tagTagRepository,
  IAppUsageTagRepository appUsageTagRepository,
  IAppUsageTimeRecordRepository appUsageTimeRecordRepository,
  ITaskRepository taskRepository,
  ITaskTagRepository taskTagRepository,
  ITaskTimeRecordRepository taskTimeRecordRepository,
  IHabitRepository habitRepository,
  IHabitRecordRepository habitRecordRepository,
  IHabitTagsRepository habitTagRepository,
  INoteTagRepository noteTagRepository,
) {
  mediator
    ..registerHandler<GetListTagsQuery, GetListTagsQueryResponse, GetListTagsQueryHandler>(
      () => GetListTagsQueryHandler(
        tagRepository: tagRepository,
      ),
    )
    ..registerHandler<GetListTagTagsQuery, GetListTagTagsQueryResponse, GetListTagTagsQueryHandler>(
      () => GetListTagTagsQueryHandler(
        tagRepository: tagRepository,
        tagTagRepository: tagTagRepository,
      ),
    )
    ..registerHandler<GetTagTimesDataQuery, GetTagTimesDataQueryResponse, GetTagTimesDataQueryHandler>(
      () => GetTagTimesDataQueryHandler(
        appUsageTimeRecordRepository: appUsageTimeRecordRepository,
        appUsageTagRepository: appUsageTagRepository,
        taskRepository: taskRepository,
        taskTagRepository: taskTagRepository,
        taskTimeRecordRepository: taskTimeRecordRepository,
      ),
    )
    ..registerHandler<GetTopTagsByTimeQuery, GetTopTagsByTimeQueryResponse, GetTopTagsByTimeQueryHandler>(
      () => GetTopTagsByTimeQueryHandler(
        appUsageTagRepository: appUsageTagRepository,
        taskTagRepository: taskTagRepository,
        habitTagRepository: habitTagRepository,
      ),
    )
    ..registerHandler<GetTagQuery, GetTagQueryResponse, GetTagQueryHandler>(
      () => GetTagQueryHandler(
        tagRepository: tagRepository,
      ),
    )
    ..registerHandler<GetElementsByTimeQuery, GetElementsByTimeQueryResponse, GetElementsByTimeQueryHandler>(
      () => GetElementsByTimeQueryHandler(
        appUsageTimeRecordRepository: appUsageTimeRecordRepository,
        appUsageTagRepository: appUsageTagRepository,
        taskTimeRecordRepository: taskTimeRecordRepository,
        taskRepository: taskRepository,
        taskTagRepository: taskTagRepository,
        habitRepository: habitRepository,
        habitRecordRepository: habitRecordRepository,
        habitTagRepository: habitTagRepository,
        tagRepository: tagRepository,
      ),
    )
    ..registerHandler<SaveTagCommand, SaveTagCommandResponse, SaveTagCommandHandler>(
      () => SaveTagCommandHandler(tagRepository: tagRepository),
    )
    ..registerHandler<DeleteTagCommand, DeleteTagCommandResponse, DeleteTagCommandHandler>(
      () => DeleteTagCommandHandler(
        tagRepository: tagRepository,
        tagTagRepository: tagTagRepository,
        taskTagRepository: taskTagRepository,
        habitTagsRepository: habitTagRepository,
        noteTagRepository: noteTagRepository,
        appUsageTagRepository: appUsageTagRepository,
      ),
    )
    ..registerHandler<AddTagTagCommand, AddTagTagCommandResponse, AddTagTagCommandHandler>(
      () => AddTagTagCommandHandler(tagTagRepository: tagTagRepository),
    )
    ..registerHandler<RemoveTagTagCommand, RemoveTagTagCommandResponse, RemoveTagTagCommandHandler>(
      () => RemoveTagTagCommandHandler(tagTagRepository: tagTagRepository),
    );
}
