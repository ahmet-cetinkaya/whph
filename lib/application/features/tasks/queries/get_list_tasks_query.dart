import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/tasks/task.dart';

class GetListTasksQuery implements IRequest<GetListTasksQueryResponse> {
  late int pageIndex;
  late int pageSize;

  GetListTasksQuery({required this.pageIndex, required this.pageSize});
}

class TaskListItem {
  int id;
  String title;
  bool isCompleted;
  EisenhowerPriority? priority;
  int? topicId;
  String? topicName;
  DateTime? plannedDate;
  DateTime? deadlineDate;

  TaskListItem({required this.id, required this.title, required this.isCompleted, this.priority});
}

class GetListTasksQueryResponse extends PaginatedList<TaskListItem> {
  GetListTasksQueryResponse(
      {required super.items,
      required super.totalItemCount,
      required super.totalPageCount,
      required super.pageIndex,
      required super.pageSize});
}

class GetListTasksQueryHandler implements IRequestHandler<GetListTasksQuery, GetListTasksQueryResponse> {
  late final ITaskRepository _taskRepository;

  GetListTasksQueryHandler({required ITaskRepository taskRepository}) : _taskRepository = taskRepository;

  @override
  Future<GetListTasksQueryResponse> call(GetListTasksQuery request) async {
    PaginatedList<Task> tasks = await _taskRepository.getList(
      request.pageIndex,
      request.pageSize,
    );

    return GetListTasksQueryResponse(
      items: tasks.items.map((e) => TaskListItem(id: e.id, title: e.title, isCompleted: e.isCompleted)).toList(),
      totalItemCount: tasks.totalItemCount,
      totalPageCount: tasks.totalPageCount,
      pageIndex: tasks.pageIndex,
      pageSize: tasks.pageSize,
    );
  }
}
