import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';

class GetListTaskTagsQuery implements IRequest<GetListTaskTagsQueryResponse> {
  late String taskId;
  late int pageIndex;
  late int pageSize;

  GetListTaskTagsQuery({required this.taskId, required this.pageIndex, required this.pageSize});
}

class TaskTagListItem {
  String id;
  String taskId;
  String tagId;
  String tagName;

  TaskTagListItem({required this.id, required this.taskId, required this.tagId, required this.tagName});
}

class GetListTaskTagsQueryResponse extends PaginatedList<TaskTagListItem> {
  GetListTaskTagsQueryResponse(
      {required super.items,
      required super.totalItemCount,
      required super.totalPageCount,
      required super.pageIndex,
      required super.pageSize});
}

class GetListTaskTagsQueryHandler implements IRequestHandler<GetListTaskTagsQuery, GetListTaskTagsQueryResponse> {
  late final ITagRepository _tagRepository;
  late final ITaskTagRepository _taskTagRepository;

  GetListTaskTagsQueryHandler({required ITagRepository tagRepository, required ITaskTagRepository taskTagRepository})
      : _tagRepository = tagRepository,
        _taskTagRepository = taskTagRepository;

  @override
  Future<GetListTaskTagsQueryResponse> call(GetListTaskTagsQuery request) async {
    PaginatedList<TaskTag> taskTags = await _taskTagRepository.getListByTaskId(
      request.taskId,
      request.pageIndex,
      request.pageSize,
    );

    List<TaskTagListItem> listItems = [];
    for (var taskTag in taskTags.items) {
      Tag secondaryTag = (await _tagRepository.getById(taskTag.tagId))!;
      listItems.add(TaskTagListItem(
        id: taskTag.id,
        taskId: taskTag.taskId,
        tagId: taskTag.tagId,
        tagName: secondaryTag.name,
      ));
    }
    return GetListTaskTagsQueryResponse(
      items: listItems,
      totalItemCount: taskTags.totalItemCount,
      totalPageCount: taskTags.totalPageCount,
      pageIndex: taskTags.pageIndex,
      pageSize: taskTags.pageSize,
    );
  }
}
