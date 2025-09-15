import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';

class GetTotalDurationByHabitIdQuery implements IRequest<GetTotalDurationByHabitIdQueryResponse> {
  final String habitId;
  final DateTime? startDate;
  final DateTime? endDate;

  GetTotalDurationByHabitIdQuery({
    required this.habitId,
    this.startDate,
    this.endDate,
  });
}

class GetTotalDurationByHabitIdQueryResponse {
  final int totalDuration;

  GetTotalDurationByHabitIdQueryResponse({
    required this.totalDuration,
  });
}

class GetTotalDurationByHabitIdQueryHandler
    implements IRequestHandler<GetTotalDurationByHabitIdQuery, GetTotalDurationByHabitIdQueryResponse> {
  final IHabitTimeRecordRepository _habitTimeRecordRepository;

  GetTotalDurationByHabitIdQueryHandler({
    required IHabitTimeRecordRepository habitTimeRecordRepository,
  }) : _habitTimeRecordRepository = habitTimeRecordRepository;

  @override
  Future<GetTotalDurationByHabitIdQueryResponse> call(GetTotalDurationByHabitIdQuery request) async {
    final totalDuration = await _habitTimeRecordRepository.getTotalDurationByHabitId(
      request.habitId,
      startDate: request.startDate,
      endDate: request.endDate,
    );

    return GetTotalDurationByHabitIdQueryResponse(totalDuration: totalDuration);
  }
}