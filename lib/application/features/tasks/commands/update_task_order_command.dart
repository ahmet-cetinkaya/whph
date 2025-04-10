import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/application/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/core/acore/repository/models/custom_order.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/core/acore/utils/order_rank.dart';

class UpdateTaskOrderCommand implements IRequest<UpdateTaskOrderResponse> {
  final String taskId;
  final String? parentTaskId;
  final double beforeTaskOrder;
  final double afterTaskOrder;

  UpdateTaskOrderCommand({
    required this.taskId,
    this.parentTaskId,
    required this.beforeTaskOrder,
    required this.afterTaskOrder,
  });
}

class UpdateTaskOrderResponse {
  final String taskId;
  final double order;

  UpdateTaskOrderResponse(this.taskId, this.order);
}

class UpdateTaskOrderCommandHandler implements IRequestHandler<UpdateTaskOrderCommand, UpdateTaskOrderResponse> {
  final ITaskRepository _taskRepository;

  UpdateTaskOrderCommandHandler(this._taskRepository);

  @override
  Future<UpdateTaskOrderResponse> call(UpdateTaskOrderCommand request) async {
    final task = await _taskRepository.getById(request.taskId);
    if (task == null) throw BusinessException(TaskTranslationKeys.taskNotFoundError);

    final otherTasks = await _taskRepository.getAll(
      customWhereFilter: CustomWhereFilter(
        'parent_task_id ${request.parentTaskId != null ? '= ?' : 'IS NULL'} AND id != ? AND deleted_date IS NULL',
        request.parentTaskId != null ? [request.parentTaskId!, task.id] : [task.id],
      ),
      customOrder: [CustomOrder(field: "order", ascending: true)],
    );

    otherTasks.sort((a, b) => a.order.compareTo(b.order));

    try {
      double newOrder;

      // Directly use the calculated afterTaskOrder from UI
      newOrder = request.afterTaskOrder;

      // Check if the newOrder is valid and make adjustments if needed
      if (otherTasks.isNotEmpty) {
        if (newOrder <= 0) {
          // If trying to move to first position but order is invalid
          newOrder = otherTasks.first.order / 2;
        } else if (newOrder >= (otherTasks.isNotEmpty ? otherTasks.last.order : 0) + OrderRank.maxOrder) {
          // If order is too large, place it properly after the last item
          newOrder = (otherTasks.last.order) + OrderRank.initialStep;
        }
      } else {
        // If there are no other tasks, use initial step
        newOrder = OrderRank.initialStep;
      }

      task.order = newOrder;
      task.modifiedDate = DateTime.now();
      await _taskRepository.update(task);

      return UpdateTaskOrderResponse(task.id, newOrder);
    } on RankGapTooSmallException {
      // Normalize all orders if gaps are too small
      double orderStep = OrderRank.initialStep;

      // Include current task in normalization
      final allTasks = [...otherTasks, task]..sort((a, b) => a.order.compareTo(b.order));

      for (var t in allTasks) {
        t.order = orderStep;
        t.modifiedDate = DateTime.now();
        await _taskRepository.update(t);
        orderStep += OrderRank.initialStep;
      }

      return UpdateTaskOrderResponse(task.id, task.order);
    }
  }
}
