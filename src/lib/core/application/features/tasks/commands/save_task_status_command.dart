import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_status_repository.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task_status.dart';

class SaveTaskStatusCommand implements IRequest<SaveTaskStatusCommandResponse> {
  final String? id;
  final String name;
  final String? color;
  final double? order;

  SaveTaskStatusCommand({
    this.id,
    required this.name,
    this.color,
    this.order,
  });
}

class SaveTaskStatusCommandResponse {
  final String id;
  final DateTime createdDate;
  final DateTime? modifiedDate;

  SaveTaskStatusCommandResponse({
    required this.id,
    required this.createdDate,
    this.modifiedDate,
  });
}

class SaveTaskStatusCommandHandler implements IRequestHandler<SaveTaskStatusCommand, SaveTaskStatusCommandResponse> {
  final ITaskStatusRepository _taskStatusRepository;

  SaveTaskStatusCommandHandler({required ITaskStatusRepository taskStatusRepository})
      : _taskStatusRepository = taskStatusRepository;

  @override
  Future<SaveTaskStatusCommandResponse> call(SaveTaskStatusCommand request) async {
    TaskStatus status;

    if (request.id != null) {
      final existing = await _taskStatusRepository.getById(request.id!);
      if (existing == null) {
        throw BusinessException('Task status not found', TaskTranslationKeys.taskStatusNotFoundError);
      }

      existing.name = request.name;
      existing.color = request.color;
      if (request.order != null) {
        existing.order = request.order!;
      }
      existing.modifiedDate = DateTime.now().toUtc();
      await _taskStatusRepository.update(existing);
      status = existing;
    } else {
      status = TaskStatus(
        id: KeyHelper.generateStringId(),
        createdDate: DateTime.now().toUtc(),
        name: request.name,
        color: request.color,
        order: request.order ?? 0.0,
      );
      await _taskStatusRepository.add(status);
    }

    return SaveTaskStatusCommandResponse(
      id: status.id,
      createdDate: status.createdDate,
      modifiedDate: status.modifiedDate,
    );
  }
}
