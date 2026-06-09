import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_status_repository.dart';
import 'package:whph/core/domain/features/tasks/task_status.dart';

class ReorderTaskStatusesCommand implements IRequest<ReorderTaskStatusesCommandResponse> {
  /// List of status IDs and their new order values.
  final List<OrderedStatus> statuses;

  ReorderTaskStatusesCommand({required this.statuses});
}

class OrderedStatus {
  final String id;
  final double order;

  OrderedStatus({required this.id, required this.order});
}

class ReorderTaskStatusesCommandResponse {
  final int count;

  ReorderTaskStatusesCommandResponse({required this.count});
}

class ReorderTaskStatusesCommandHandler
    implements IRequestHandler<ReorderTaskStatusesCommand, ReorderTaskStatusesCommandResponse> {
  final ITaskStatusRepository _taskStatusRepository;

  ReorderTaskStatusesCommandHandler({required ITaskStatusRepository taskStatusRepository})
      : _taskStatusRepository = taskStatusRepository;

  @override
  Future<ReorderTaskStatusesCommandResponse> call(ReorderTaskStatusesCommand request) async {
    if (request.statuses.isEmpty) {
      return ReorderTaskStatusesCommandResponse(count: 0);
    }

    // Fetch all statuses to update
    final statuses = await Future.wait(request.statuses.map((s) => _taskStatusRepository.getById(s.id)));

    // Filter out nulls and update order
    final toUpdate = <TaskStatus>[];
    for (var i = 0; i < statuses.length; i++) {
      final status = statuses[i];
      final orderData = request.statuses[i];
      if (status != null) {
        status.order = orderData.order;
        toUpdate.add(status);
      }
    }

    // Batch update all at once
    await _taskStatusRepository.updateMultiple(toUpdate);

    return ReorderTaskStatusesCommandResponse(count: toUpdate.length);
  }
}
