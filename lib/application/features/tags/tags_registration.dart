import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/commands/add_tag_tag_command.dart';
import 'package:whph/application/features/tags/commands/delete_tag_command.dart';
import 'package:whph/application/features/tags/commands/remove_tag_tag_command.dart';
import 'package:whph/application/features/tags/queries/get_list_tag_tags_query.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/application/features/tags/queries/get_tag_query.dart';
import 'package:whph/application/features/tags/queries/get_tag_times_data_query.dart';
import 'package:whph/application/features/tags/queries/get_top_tags_by_time_query.dart';
import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';

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
) {
  mediator
    ..registerHandler<SaveTagCommand, SaveTagCommandResponse, SaveTagCommandHandler>(
      () => SaveTagCommandHandler(tagRepository: tagRepository),
    )
    ..registerHandler<DeleteTagCommand, DeleteTagCommandResponse, DeleteTagCommandHandler>(
      () => DeleteTagCommandHandler(tagRepository: tagRepository),
    )
    ..registerHandler<GetListTagsQuery, GetListTagsQueryResponse, GetListTagsQueryHandler>(
      () => GetListTagsQueryHandler(tagRepository: tagRepository),
    )
    ..registerHandler<GetTagQuery, GetTagQueryResponse, GetTagQueryHandler>(
      () => GetTagQueryHandler(tagRepository: tagRepository),
    )
    ..registerHandler<AddTagTagCommand, AddTagTagCommandResponse, AddTagTagCommandHandler>(
      () => AddTagTagCommandHandler(tagTagRepository: tagTagRepository),
    )
    ..registerHandler<RemoveTagTagCommand, RemoveTagTagCommandResponse, RemoveTagTagCommandHandler>(
      () => RemoveTagTagCommandHandler(tagTagRepository: tagTagRepository),
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
      ),
    );
}
