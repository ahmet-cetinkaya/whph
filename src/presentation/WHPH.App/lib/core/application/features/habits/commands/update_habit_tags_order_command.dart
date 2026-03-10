import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/i_habit_tags_repository.dart';

class UpdateHabitTagsOrderCommand implements IRequest<void> {
  final String habitId;
  final Map<String, int> tagOrders;

  UpdateHabitTagsOrderCommand({
    required this.habitId,
    required this.tagOrders,
  });
}

class UpdateHabitTagsOrderCommandHandler implements IRequestHandler<UpdateHabitTagsOrderCommand, void> {
  final IHabitTagsRepository _habitTagRepository;

  UpdateHabitTagsOrderCommandHandler({required IHabitTagsRepository habitTagRepository})
      : _habitTagRepository = habitTagRepository;

  @override
  Future<void> call(UpdateHabitTagsOrderCommand request) async {
    await _habitTagRepository.updateTagOrders(request.habitId, request.tagOrders);
  }
}
