import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/habit_record_operations_service.dart';
import 'package:whph/core/application/features/habits/services/habit_day_state_resolver.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:acore/acore.dart';

class AddHabitRecordCommand implements IRequest<AddHabitRecordCommandResponse> {
  final String habitId;
  final DateTime occurredAt;

  AddHabitRecordCommand({
    required this.habitId,
    DateTime? occurredAt,
  }) : occurredAt = occurredAt != null ? DateTimeHelper.toUtcDateTime(occurredAt) : DateTime.now().toUtc();
}

class AddHabitRecordCommandResponse {}

class AddHabitRecordCommandHandler implements IRequestHandler<AddHabitRecordCommand, AddHabitRecordCommandResponse> {
  final IHabitRecordRepository _habitRecordRepository;
  final IHabitRepository _habitRepository;
  final HabitRecordOperationsService _operationsService;

  AddHabitRecordCommandHandler({
    required IHabitRecordRepository habitRecordRepository,
    required IHabitRepository habitRepository,
    required HabitRecordOperationsService operationsService,
  })  : _habitRecordRepository = habitRecordRepository,
        _habitRepository = habitRepository,
        _operationsService = operationsService;

  @override
  Future<AddHabitRecordCommandResponse> call(AddHabitRecordCommand request) async {
    final habit = await _habitRepository.getById(request.habitId);
    if (habit?.type == HabitType.bad) {
      final dayRange = HabitDayStateResolver.utcRangeFor(request.occurredAt);
      final records = await _habitRecordRepository.getListByHabitIdAndRangeDate(
        request.habitId,
        dayRange.start,
        dayRange.end,
        0,
        1000,
      );
      await _operationsService.ensureBadHabitMarker(request.habitId, request.occurredAt, records.items);
      return AddHabitRecordCommandResponse();
    }

    await _operationsService.addHabitRecord(
      request.habitId,
      request.occurredAt,
      HabitRecordStatus.complete,
      DateTime.now().toUtc(),
    );
    if (habit != null) {
      await _operationsService.addTimeRecordIfComplete(
        habit,
        request.habitId,
        request.occurredAt,
        HabitRecordStatus.complete,
      );
    }

    return AddHabitRecordCommandResponse();
  }
}
