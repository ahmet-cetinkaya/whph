import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/core/application/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';

class AppUsageTimeRecordListItem {
  const AppUsageTimeRecordListItem(
      {required this.id,
      required this.occurredAt,
      required this.durationSeconds});

  final String id;
  final DateTime occurredAt;
  final int durationSeconds;
}

class GetAppUsageQuery implements IRequest<GetAppUsageQueryResponse> {
  final String id;

  GetAppUsageQuery({required this.id});
}

class GetAppUsageQueryResponse {
  final String name;
  final String? displayName;
  final String? color;
  final String? deviceName;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final List<AppUsageTimeRecordListItem> timeRecords;
  final bool hasMoreTimeRecords;

  GetAppUsageQueryResponse({
    required this.name,
    this.displayName,
    this.color,
    this.deviceName,
    required this.createdDate,
    this.modifiedDate,
    required List<AppUsageTimeRecordListItem> timeRecords,
    required this.hasMoreTimeRecords,
  }) : timeRecords = List.unmodifiable(timeRecords);

  GetAppUsageQueryResponse withColor(String? nextColor) =>
      GetAppUsageQueryResponse(
        name: name,
        displayName: displayName,
        color: nextColor,
        deviceName: deviceName,
        createdDate: createdDate,
        modifiedDate: modifiedDate,
        timeRecords: timeRecords,
        hasMoreTimeRecords: hasMoreTimeRecords,
      );
}

class GetAppUsageQueryHandler
    implements IRequestHandler<GetAppUsageQuery, GetAppUsageQueryResponse> {
  late final IAppUsageRepository _appUsageRepository;
  late final IAppUsageTimeRecordRepository _timeRecordRepository;

  GetAppUsageQueryHandler({
    required IAppUsageRepository appUsageRepository,
    required IAppUsageTimeRecordRepository timeRecordRepository,
  })  : _appUsageRepository = appUsageRepository,
        _timeRecordRepository = timeRecordRepository;

  @override
  Future<GetAppUsageQueryResponse> call(GetAppUsageQuery request) async {
    AppUsage? appUsages = await _appUsageRepository.getById(request.id);
    if (appUsages == null) {
      throw BusinessException(
          'App usage not found', AppUsageTranslationKeys.appUsageNotFoundError);
    }
    final timeRecords = await _timeRecordRepository.getList(
      0,
      200,
      customWhereFilter: CustomWhereFilter('app_usage_id = ?', [request.id]),
      customOrder: [
        CustomOrder(field: 'usage_date', direction: SortDirection.desc)
      ],
    );

    return GetAppUsageQueryResponse(
      name: appUsages.name,
      displayName: appUsages.displayName,
      color: appUsages.color,
      deviceName: appUsages.deviceName,
      createdDate: appUsages.createdDate,
      modifiedDate: appUsages.modifiedDate,
      timeRecords: timeRecords.items
          .map((record) => AppUsageTimeRecordListItem(
                id: record.id,
                occurredAt: record.usageDate,
                durationSeconds: record.duration,
              ))
          .toList(growable: false),
      hasMoreTimeRecords: timeRecords.hasNext,
    );
  }
}
