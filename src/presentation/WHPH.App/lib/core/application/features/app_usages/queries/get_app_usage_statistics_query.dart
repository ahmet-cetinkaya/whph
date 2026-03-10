import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:acore/acore.dart';

class GetAppUsageStatisticsQuery implements IRequest<GetAppUsageStatisticsResponse> {
  final String appUsageId;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? compareStartDate;
  final DateTime? compareEndDate;

  GetAppUsageStatisticsQuery({
    required this.appUsageId,
    required DateTime startDate,
    required DateTime endDate,
    DateTime? compareStartDate,
    DateTime? compareEndDate,
  })  : startDate = DateTimeHelper.toUtcDateTime(startDate),
        endDate = DateTimeHelper.toUtcDateTime(endDate),
        compareStartDate = compareStartDate != null ? DateTimeHelper.toUtcDateTime(compareStartDate) : null,
        compareEndDate = compareEndDate != null ? DateTimeHelper.toUtcDateTime(compareEndDate) : null;
}

class DailyUsageData {
  final int dayOfWeek; // 1-7 (Monday-Sunday)
  final int totalDuration;
  int? compareDuration;

  DailyUsageData({
    required this.dayOfWeek,
    required this.totalDuration,
    this.compareDuration,
  });
}

class HourlyUsageData {
  final int hour; // 0-23
  final int totalDuration;
  int? compareDuration;

  HourlyUsageData({
    required this.hour,
    required this.totalDuration,
    this.compareDuration,
  });
}

class GetAppUsageStatisticsResponse {
  final List<DailyUsageData> dailyUsage;
  final List<HourlyUsageData> hourlyUsage;
  final int totalDuration;
  final int? compareTotalDuration;

  GetAppUsageStatisticsResponse({
    required this.dailyUsage,
    required this.hourlyUsage,
    required this.totalDuration,
    this.compareTotalDuration,
  });
}

class GetAppUsageStatisticsQueryHandler
    implements IRequestHandler<GetAppUsageStatisticsQuery, GetAppUsageStatisticsResponse> {
  final IAppUsageTimeRecordRepository _appUsageTimeRecordRepository;

  GetAppUsageStatisticsQueryHandler({
    required IAppUsageTimeRecordRepository appUsageTimeRecordRepository,
  }) : _appUsageTimeRecordRepository = appUsageTimeRecordRepository;

  @override
  Future<GetAppUsageStatisticsResponse> call(GetAppUsageStatisticsQuery request) async {
    // Get daily data
    final dailyData = await _getDailyUsageData(
      request.appUsageId,
      DateTimeHelper.toUtcDateTime(request.startDate),
      DateTimeHelper.toUtcDateTime(request.endDate),
    );

    // Get hourly data
    final hourlyData = await _getHourlyUsageData(
      request.appUsageId,
      DateTimeHelper.toUtcDateTime(request.startDate),
      DateTimeHelper.toUtcDateTime(request.endDate),
    );

    // Get comparison data if needed
    List<DailyUsageData>? compareDailyData;
    List<HourlyUsageData>? compareHourlyData;
    int? compareTotalDuration;

    if (request.compareStartDate != null && request.compareEndDate != null) {
      compareDailyData = await _getDailyUsageData(
        request.appUsageId,
        DateTimeHelper.toUtcDateTime(request.compareStartDate!),
        DateTimeHelper.toUtcDateTime(request.compareEndDate!),
      );

      compareHourlyData = await _getHourlyUsageData(
        request.appUsageId,
        DateTimeHelper.toUtcDateTime(request.compareStartDate!),
        DateTimeHelper.toUtcDateTime(request.compareEndDate!),
      );

      // Merge comparison data with primary data
      for (final dayData in dailyData) {
        final compareDay = compareDailyData.firstWhere(
          (d) => d.dayOfWeek == dayData.dayOfWeek,
          orElse: () => DailyUsageData(dayOfWeek: dayData.dayOfWeek, totalDuration: 0),
        );
        dayData.compareDuration = compareDay.totalDuration;
      }

      for (final hourData in hourlyData) {
        final compareHour = compareHourlyData.firstWhere(
          (h) => h.hour == hourData.hour,
          orElse: () => HourlyUsageData(hour: hourData.hour, totalDuration: 0),
        );
        hourData.compareDuration = compareHour.totalDuration;
      }

      // Calculate total compare duration
      compareTotalDuration = compareDailyData.fold(0, (sum, data) => sum! + data.totalDuration);
    }

    // Calculate total duration
    final totalDuration = dailyData.fold(0, (sum, data) => sum + data.totalDuration);

    return GetAppUsageStatisticsResponse(
      dailyUsage: dailyData,
      hourlyUsage: hourlyData,
      totalDuration: totalDuration,
      compareTotalDuration: compareTotalDuration,
    );
  }

  Future<List<DailyUsageData>> _getDailyUsageData(
    String appUsageId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Since we don't have a direct SQL query for day-of-week stats,
    // we'll need to get all records in the date range and group them in code
    final timeRecords = await _appUsageTimeRecordRepository.getAll(
      customWhereFilter: CustomWhereFilter(
        'app_usage_id = ? AND usage_date >= ? AND usage_date <= ? AND deleted_date IS NULL',
        [appUsageId, startDate, endDate],
      ),
    );

    // Initialize map for all days of the week
    final Map<int, int> dailyUsage = {
      1: 0, // Monday
      2: 0, // Tuesday
      3: 0, // Wednesday
      4: 0, // Thursday
      5: 0, // Friday
      6: 0, // Saturday
      7: 0, // Sunday
    };

    // Aggregate durations by day of week
    for (final record in timeRecords) {
      // DateTime weekday is 1-7 where 1 is Monday and 7 is Sunday
      final dayOfWeek = record.usageDate.weekday;
      dailyUsage[dayOfWeek] = dailyUsage[dayOfWeek]! + record.duration;
    }

    // Convert map to list of DailyUsageData
    return dailyUsage.entries
        .map((entry) => DailyUsageData(
              dayOfWeek: entry.key,
              totalDuration: entry.value,
            ))
        .toList();
  }

  Future<List<HourlyUsageData>> _getHourlyUsageData(
    String appUsageId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Get all records in the date range
    final timeRecords = await _appUsageTimeRecordRepository.getAll(
      customWhereFilter: CustomWhereFilter(
        'app_usage_id = ? AND usage_date >= ? AND usage_date <= ? AND deleted_date IS NULL',
        [appUsageId, startDate, endDate],
      ),
    );

    // Initialize map for all hours of the day
    final Map<int, int> hourlyUsage = {};
    for (int i = 0; i < 24; i++) {
      hourlyUsage[i] = 0;
    }

    // Aggregate durations by hour of day
    for (final record in timeRecords) {
      final hour = record.usageDate.hour;
      hourlyUsage[hour] = hourlyUsage[hour]! + record.duration;
    }

    // Convert map to list of HourlyUsageData
    return hourlyUsage.entries
        .map((entry) => HourlyUsageData(
              hour: entry.key,
              totalDuration: entry.value,
            ))
        .toList()
      ..sort((a, b) => a.hour.compareTo(b.hour)); // Sort by hour
  }
}
