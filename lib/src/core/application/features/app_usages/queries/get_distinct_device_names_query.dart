import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';

class GetDistinctDeviceNamesQuery implements IRequest<GetDistinctDeviceNamesQueryResponse> {}

class GetDistinctDeviceNamesQueryResponse {
  final List<String> deviceNames;

  GetDistinctDeviceNamesQueryResponse({required this.deviceNames});
}

class GetDistinctDeviceNamesQueryHandler
    implements IRequestHandler<GetDistinctDeviceNamesQuery, GetDistinctDeviceNamesQueryResponse> {
  final IAppUsageTimeRecordRepository _timeRecordRepository;

  GetDistinctDeviceNamesQueryHandler({
    required IAppUsageTimeRecordRepository timeRecordRepository,
  }) : _timeRecordRepository = timeRecordRepository;

  @override
  Future<GetDistinctDeviceNamesQueryResponse> call(GetDistinctDeviceNamesQuery request) async {
    final deviceNames = await _timeRecordRepository.getDistinctDeviceNames();
    return GetDistinctDeviceNamesQueryResponse(deviceNames: deviceNames);
  }
}
