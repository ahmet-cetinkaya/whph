import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/application/shared/utils/key_helper.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';
import 'package:whph/domain/features/habits/habit_tag.dart';
import 'package:whph/application/features/habits/constants/habit_translation_keys.dart';

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

class AddHabitTagCommandHandler implements IRequestHandler<AddHabitTagCommand, AddHabitTagCommandResponse> {
  final IHabitTagsRepository _habitTagRepository;

  AddHabitTagCommandHandler({required IHabitTagsRepository habitTagRepository})
      : _habitTagRepository = habitTagRepository;

  @override
  Future<AddHabitTagCommandResponse> call(AddHabitTagCommand request) async {
    if (await _habitTagRepository.anyByHabitIdAndTagId(request.habitId, request.tagId)) {
      throw BusinessException(HabitTranslationKeys.habitTagAlreadyExistsError);
    }

    final habitTag = HabitTag(
      id: KeyHelper.generateStringId(),
      createdDate: DateTimeHelper.toUtcDateTime(DateTime.now()),
      habitId: request.habitId,
      tagId: request.tagId,
    );
    await _habitTagRepository.add(habitTag);

    return AddHabitTagCommandResponse(
      id: habitTag.id,
    );
  }
}
