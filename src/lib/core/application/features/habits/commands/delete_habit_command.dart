import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_cascade_service.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_events.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/application/features/habits/constants/habit_translation_keys.dart';

class DeleteHabitCommand implements IRequest<DeleteHabitCommandResponse> {
  final String id;

  DeleteHabitCommand({required this.id});
}

class DeleteHabitCommandResponse {}

class DeleteHabitCommandHandler implements IRequestHandler<DeleteHabitCommand, DeleteHabitCommandResponse> {
  final IHabitRepository _habitRepository;
  final IHabitTagsRepository _habitTagsRepository;
  final IHabitRecordRepository _habitRecordRepository;
  final IHabitEvents? _habitEvents;
  final ISyncCascadeService _syncCascadeService;

  DeleteHabitCommandHandler({
    required IHabitRepository habitRepository,
    required IHabitTagsRepository habitTagsRepository,
    required IHabitRecordRepository habitRecordRepository,
    IHabitEvents? habitEvents,
    required ISyncCascadeService syncCascadeService,
  })  : _habitRepository = habitRepository,
        _habitTagsRepository = habitTagsRepository,
        _habitRecordRepository = habitRecordRepository,
        _habitEvents = habitEvents,
        _syncCascadeService = syncCascadeService;

  @override
  Future<DeleteHabitCommandResponse> call(DeleteHabitCommand request) async {
    Habit? habit = await _habitRepository.getById(request.id);
    if (habit == null) {
      throw BusinessException('Habit not found', HabitTranslationKeys.habitNotFoundError);
    }

    // Cascade delete: Delete all related entities first, stamped with the
    // root habit as their tombstone cause (D5b).
    await _syncCascadeService.withCause('habit_table', habit.id, () async {
      await _deleteRelatedEntities(request.id);
      await _habitRepository.delete(habit);
    });
    _habitEvents?.notifyHabitDeleted(habit.id);

    return DeleteHabitCommandResponse();
  }

  /// Deletes all entities related to the habit
  Future<void> _deleteRelatedEntities(String habitId) async {
    // Delete habit tags
    final habitTags = await _habitTagsRepository.getByHabitId(habitId);
    for (final habitTag in habitTags) {
      await _habitTagsRepository.delete(habitTag);
    }

    // Delete habit records
    final habitRecords = await _habitRecordRepository.getByHabitId(habitId);
    for (final habitRecord in habitRecords) {
      await _habitRecordRepository.delete(habitRecord);
    }
  }
}
