import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/domain/features/habits/habit_record.dart';

class GetListHabitRecordsQuery implements IRequest<GetListHabitRecordsQueryResponse> {
  String habitId;
  DateTime startDate;
  DateTime endDate;

  int pageIndex;
  int pageSize;

  GetListHabitRecordsQuery(
      {required this.pageIndex,
      required this.pageSize,
      required this.habitId,
      required DateTime startDate,
      required DateTime endDate})
      : startDate = DateTimeHelper.toUtcDateTime(startDate),
        endDate = DateTimeHelper.toUtcDateTime(endDate);
}

class HabitRecordListItem {
  String id;
  DateTime date;

  HabitRecordListItem({required this.id, required this.date});
}

class GetListHabitRecordsQueryResponse extends PaginatedList<HabitRecordListItem> {
  GetListHabitRecordsQueryResponse(
      {required super.items, required super.totalItemCount, required super.pageIndex, required super.pageSize});
}

class GetListHabitRecordsQueryHandler
    implements IRequestHandler<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse> {
  late final IHabitRecordRepository _habitRepository;

  GetListHabitRecordsQueryHandler({required IHabitRecordRepository habitRecordRepository})
      : _habitRepository = habitRecordRepository;

  @override
  Future<GetListHabitRecordsQueryResponse> call(GetListHabitRecordsQuery request) async {
    PaginatedList<HabitRecord> habitRecords = await _habitRepository.getListByHabitIdAndRangeDate(
      request.habitId,
      request.startDate,
      request.endDate,
      request.pageIndex,
      request.pageSize,
    );

    return GetListHabitRecordsQueryResponse(
      items: habitRecords.items.map((e) => HabitRecordListItem(id: e.id, date: e.date)).toList(),
      totalItemCount: habitRecords.totalItemCount,
      pageIndex: habitRecords.pageIndex,
      pageSize: habitRecords.pageSize,
    );
  }
}
