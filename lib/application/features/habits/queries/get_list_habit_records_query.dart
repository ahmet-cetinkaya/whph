import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/habits/habit_record.dart';

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
      required this.startDate,
      required this.endDate});
}

class HabitRecordListItem {
  String id;
  DateTime date;

  HabitRecordListItem({required this.id, required this.date});
}

class GetListHabitRecordsQueryResponse extends PaginatedList<HabitRecordListItem> {
  GetListHabitRecordsQueryResponse(
      {required super.items,
      required super.totalItemCount,
      required super.totalPageCount,
      required super.pageIndex,
      required super.pageSize});
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
      totalPageCount: habitRecords.totalPageCount,
      pageIndex: habitRecords.pageIndex,
      pageSize: habitRecords.pageSize,
    );
  }
}
