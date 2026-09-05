import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/models/sync_data.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_validation_service.dart';
import 'package:whph/core/application/features/sync/services/sync_communication_service/helpers/sync_dto_serializer.dart';
import 'package:whph/core/application/features/sync/services/sync_pagination_service/helpers/sync_dto_builder.dart';
import 'package:whph/core/application/features/sync/services/sync_validation_service.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';

import '../../../../infrastructure/desktop/features/sync/desktop_sync_service_test.mocks.dart';

void main() {
  final syncDevice = SyncDevice(
    id: 'sync-device',
    createdDate: DateTime.utc(2026),
    fromIp: '127.0.0.1',
    toIp: '127.0.0.2',
    fromDeviceId: 'from',
    toDeviceId: 'to',
  );

  test('same-version DTO round-trip preserves both habit types', () async {
    final habits = [
      _habit('good', HabitType.good),
      _habit('bad', HabitType.bad),
    ];
    final paginatedData = PaginatedSyncData<Habit>(
      data: SyncData(createSync: habits, updateSync: [], deleteSync: []),
      pageIndex: 0,
      pageSize: 200,
      totalPages: 1,
      totalItems: habits.length,
      isLastPage: true,
      entityType: 'Habit',
    );
    final dto = SyncDtoBuilder().buildDto(
      syncDevice: syncDevice,
      paginatedData: paginatedData,
      entityType: 'Habit',
    );

    final json = await SyncDtoSerializer().convertDtoToJson(dto);
    final restored = PaginatedSyncDataDto.fromJson(json);

    expect(restored.appVersion, AppInfo.version);
    expect(
      restored.habitsSyncData!.data.createSync.map((habit) => habit.type),
      orderedEquals([HabitType.good, HabitType.bad]),
    );
  });

  test('version mismatch remains rejected', () async {
    final service = SyncValidationService(deviceIdService: MockIDeviceIdService());

    expect(
      () => service.validateVersion('${AppInfo.version}-different'),
      throwsA(isA<SyncValidationException>()),
    );
  });
}

Habit _habit(String id, HabitType type) => Habit(
      id: id,
      createdDate: DateTime.utc(2026),
      type: type,
      name: id,
      description: '',
    );
