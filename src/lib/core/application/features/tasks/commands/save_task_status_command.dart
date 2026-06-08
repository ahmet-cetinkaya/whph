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
  static const int _maxNameLength = 50;
  static final RegExp _hexColorRegex = RegExp(r'^[0-9A-Fa-f]{6}$');

  final ITaskStatusRepository _taskStatusRepository;

  SaveTaskStatusCommandHandler({required ITaskStatusRepository taskStatusRepository})
      : _taskStatusRepository = taskStatusRepository;

  @override
  Future<SaveTaskStatusCommandResponse> call(SaveTaskStatusCommand request) async {
    _validate(request);
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

  void _validate(SaveTaskStatusCommand request) {
    if (request.name.trim().isEmpty) {
      throw BusinessException('Status name cannot be empty', TaskTranslationKeys.taskStatusNotFoundError);
    }
    if (request.name.length > _maxNameLength) {
      throw BusinessException(
        'Status name cannot exceed $_maxNameLength characters',
        TaskTranslationKeys.taskStatusNotFoundError,
      );
    }
    if (request.color != null && request.color!.isNotEmpty && !_hexColorRegex.hasMatch(request.color!)) {
      throw BusinessException(
        'Invalid color format. Expected 6-digit hex (e.g. FF5722)',
        TaskTranslationKeys.taskStatusNotFoundError,
      );
    }
  }
}
