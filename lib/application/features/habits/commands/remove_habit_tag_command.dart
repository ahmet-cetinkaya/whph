import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/services/i_habit_tags_repository.dart';

import 'package:whph/domain/features/habits/habit_tag.dart';

class RemoveHabitTagCommand implements IRequest<RemoveHabitTagCommandResponse> {
  String id;

  RemoveHabitTagCommand({
    required this.id,
  });
}

class RemoveHabitTagCommandResponse {
  final String id;

  RemoveHabitTagCommandResponse({
    required this.id,
  });
}

class RemoveHabitTagCommandHandler implements IRequestHandler<RemoveHabitTagCommand, RemoveHabitTagCommandResponse> {
  final IHabitTagsRepository _habitTagRepository;

  RemoveHabitTagCommandHandler({required IHabitTagsRepository habitTagRepository})
      : _habitTagRepository = habitTagRepository;

  @override
  Future<RemoveHabitTagCommandResponse> call(RemoveHabitTagCommand request) async {
    HabitTag? habitTag = await _habitTagRepository.getById(request.id);
    if (habitTag == null) {
      throw Exception('HabitTag with id ${request.id} not found');
    }
    await _habitTagRepository.delete(habitTag);

    return RemoveHabitTagCommandResponse(
      id: habitTag.id,
    );
  }
}
