import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/shared/utils/sync_identity.dart';
import 'package:whph/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/habits/habit_tag.dart';
import 'package:whph/core/application/features/habits/constants/habit_translation_keys.dart';

class AddHabitTagCommand implements IRequest<AddHabitTagCommandResponse> {
  String habitId;
  String tagId;

  AddHabitTagCommand({
    required this.habitId,
    required this.tagId,
  });
}

class AddHabitTagCommandResponse {
  final String id;

  AddHabitTagCommandResponse({
    required this.id,
  });
}

class AddHabitTagCommandHandler
    implements IRequestHandler<AddHabitTagCommand, AddHabitTagCommandResponse> {
  final IHabitTagsRepository _habitTagRepository;

  AddHabitTagCommandHandler({required IHabitTagsRepository habitTagRepository})
      : _habitTagRepository = habitTagRepository;

  @override
  Future<AddHabitTagCommandResponse> call(AddHabitTagCommand request) async {
    if (await _habitTagRepository.anyByHabitIdAndTagId(
        request.habitId, request.tagId)) {
      throw BusinessException('Habit tag already exists',
          HabitTranslationKeys.habitTagAlreadyExistsError);
    }

    final habitTag = HabitTag(
      id: syncIdentityId(
          identityKindHabitTag, [request.habitId, request.tagId]),
      createdDate: DateTime.now().toUtc(),
      habitId: request.habitId,
      tagId: request.tagId,
    );
    await _habitTagRepository.upsertRevive(habitTag);

    return AddHabitTagCommandResponse(
      id: habitTag.id,
    );
  }
}
