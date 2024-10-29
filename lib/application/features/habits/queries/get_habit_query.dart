import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/domain/features/habits/habit.dart';

class GetHabitQuery implements IRequest<GetHabitQueryResponse> {
  late String? id;

  GetHabitQuery({this.id});
}

class HabitHabitListItem {
  String id;
  String name;

  HabitHabitListItem({
    required this.id,
    required this.name,
  });
}

class GetHabitQueryResponse extends Habit {
  GetHabitQueryResponse({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required super.name,
    required super.description,
  });
}

class GetHabitQueryHandler implements IRequestHandler<GetHabitQuery, GetHabitQueryResponse> {
  late final IHabitRepository _habitRepository;

  GetHabitQueryHandler({required IHabitRepository habitRepository}) : _habitRepository = habitRepository;

  @override
  Future<GetHabitQueryResponse> call(GetHabitQuery request) async {
    Habit? habit = await _habitRepository.getById(
      request.id!,
    );
    if (habit == null) {
      throw Exception('Habit with id ${request.id} not found');
    }

    return GetHabitQueryResponse(
      id: habit.id,
      createdDate: habit.createdDate,
      modifiedDate: habit.modifiedDate,
      name: habit.name,
      description: habit.description,
    );
  }
}
