// ignore_for_file: unused_local_variable

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_constants.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/features/tasks/services/default_task_settings_service.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';

import 'default_task_settings_service_test.mocks.dart';

// Test logger that discards all log messages
class TestLogger implements ILogger {
  const TestLogger();

  @override
  void debug(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void info(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void error(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void fatal(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
}

@GenerateMocks([
  Mediator,
])
void main() {
  late MockMediator mockMediator;
  late DefaultTaskSettingsService service;

  setUp(() {
    mockMediator = MockMediator();
    service = DefaultTaskSettingsService(mockMediator, const TestLogger());
  });

  group('DefaultTaskSettingsService Tests - Estimated Time', () {
    test('should return configured estimated time', () async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskDefaultEstimatedTime,
        value: '45',
        valueType: SettingValueType.int,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);

      // Act
      final result = await service.getDefaultEstimatedTime();

      // Assert
      expect(result, equals(45));
      verify(mockMediator.send<GetSettingQuery, Setting?>(captureThat(
        predicate<GetSettingQuery>((q) => q.key == SettingKeys.taskDefaultEstimatedTime),
      ))).called(1);
    });

    test('should return default estimated time when setting not found', () async {
      // Arrange
      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => null);

      // Act
      final result = await service.getDefaultEstimatedTime();

      // Assert
      expect(result, isNull);
    });

    test('should return default estimated time when setting value is 0', () async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskDefaultEstimatedTime,
        value: '0',
        valueType: SettingValueType.int,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);

      // Act
      final result = await service.getDefaultEstimatedTime();

      // Assert
      expect(result, isNull);
    });

    test('should return default estimated time on error', () async {
      // Arrange
      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenThrow(Exception('Database error'));

      // Act
      final result = await service.getDefaultEstimatedTime();

      // Assert
      expect(result, isNull);
    });

    test('should cache estimated time after first load', () async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskDefaultEstimatedTime,
        value: '30',
        valueType: SettingValueType.int,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);

      // Act - Call twice
      final result1 = await service.getDefaultEstimatedTime();
      final result2 = await service.getDefaultEstimatedTime();

      // Assert
      expect(result1, equals(30));
      expect(result2, equals(30));
      // Should only call mediator once due to caching
      verify(mockMediator.send<GetSettingQuery, Setting?>(any)).called(1);
    });

    test('should invalidate cache when clearCache is called', () async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskDefaultEstimatedTime,
        value: '25',
        valueType: SettingValueType.int,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);

      // Act - First load
      final result1 = await service.getDefaultEstimatedTime();
      service.clearCache();
      // Second load after cache clear
      final result2 = await service.getDefaultEstimatedTime();

      // Assert
      expect(result1, equals(25));
      expect(result2, equals(25));
      // Should call mediator twice due to cache clear
      verify(mockMediator.send<GetSettingQuery, Setting?>(any)).called(2);
    });
  });

  group('DefaultTaskSettingsService Tests - Planned Date Reminder', () {
    test('should return configured reminder settings', () async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskDefaultPlannedDateReminder,
        value: ReminderTime.fifteenMinutesBefore.name,
        valueType: SettingValueType.string,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);

      // Act
      final result = await service.getDefaultPlannedDateReminder();

      // Assert
      expect(result.$1, equals(ReminderTime.fifteenMinutesBefore));
      expect(result.$2, isNull);
      verify(mockMediator.send<GetSettingQuery, Setting?>(captureThat(
        predicate<GetSettingQuery>((q) => q.key == SettingKeys.taskDefaultPlannedDateReminder),
      ))).called(1);
    });

    test('should return default reminder settings when not found', () async {
      // Arrange
      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => null);

      // Act
      final result = await service.getDefaultPlannedDateReminder();

      // Assert
      expect(result.$1, equals(TaskConstants.defaultReminderTime));
      expect(result.$2, isNull);
    });

    test('should return default reminder settings on error', () async {
      // Arrange
      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenThrow(Exception('Database error'));

      // Act
      final result = await service.getDefaultPlannedDateReminder();

      // Assert
      expect(result.$1, equals(TaskConstants.defaultReminderTime));
      expect(result.$2, isNull);
    });

    test('should return custom offset when reminder is custom', () async {
      // Arrange
      final reminderSetting = Setting(
        id: 'reminder-setting-id',
        key: SettingKeys.taskDefaultPlannedDateReminder,
        value: ReminderTime.custom.name,
        valueType: SettingValueType.string,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      final offsetSetting = Setting(
        id: 'offset-setting-id',
        key: SettingKeys.taskDefaultPlannedDateReminderCustomOffset,
        value: '45',
        valueType: SettingValueType.int,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(captureThat(
        predicate<GetSettingQuery>((q) => q.key == SettingKeys.taskDefaultPlannedDateReminder),
      ))).thenAnswer((_) async => reminderSetting);

      when(mockMediator.send<GetSettingQuery, Setting?>(captureThat(
        predicate<GetSettingQuery>((q) => q.key == SettingKeys.taskDefaultPlannedDateReminderCustomOffset),
      ))).thenAnswer((_) async => offsetSetting);

      // Act
      final result = await service.getDefaultPlannedDateReminder();

      // Assert
      expect(result.$1, equals(ReminderTime.custom));
      expect(result.$2, equals(45));
    });

    test('should return null custom offset when reminder is custom but offset not found', () async {
      // Arrange
      final reminderSetting = Setting(
        id: 'reminder-setting-id',
        key: SettingKeys.taskDefaultPlannedDateReminder,
        value: ReminderTime.custom.name,
        valueType: SettingValueType.string,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(captureThat(
        predicate<GetSettingQuery>((q) => q.key == SettingKeys.taskDefaultPlannedDateReminder),
      ))).thenAnswer((_) async => reminderSetting);

      when(mockMediator.send<GetSettingQuery, Setting?>(captureThat(
        predicate<GetSettingQuery>((q) => q.key == SettingKeys.taskDefaultPlannedDateReminderCustomOffset),
      ))).thenAnswer((_) async => null);

      // Act
      final result = await service.getDefaultPlannedDateReminder();

      // Assert
      expect(result.$1, equals(ReminderTime.custom));
      expect(result.$2, isNull);
    });

    test('should cache reminder settings after first load', () async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskDefaultPlannedDateReminder,
        value: ReminderTime.oneHourBefore.name,
        valueType: SettingValueType.string,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);

      // Act - Call twice
      final result1 = await service.getDefaultPlannedDateReminder();
      final result2 = await service.getDefaultPlannedDateReminder();

      // Assert
      expect(result1.$1, equals(ReminderTime.oneHourBefore));
      expect(result2.$1, equals(ReminderTime.oneHourBefore));
      // Should only call mediator once due to caching
      verify(mockMediator.send<GetSettingQuery, Setting?>(any)).called(1);
    });

    test('should invalidate cache when clearCache is called for reminder', () async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskDefaultPlannedDateReminder,
        value: ReminderTime.atTime.name,
        valueType: SettingValueType.string,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);

      // Act - First load
      final result1 = await service.getDefaultPlannedDateReminder();
      service.clearCache();
      // Second load after cache clear
      final result2 = await service.getDefaultPlannedDateReminder();

      // Assert
      expect(result1.$1, equals(ReminderTime.atTime));
      expect(result2.$1, equals(ReminderTime.atTime));
      // Should call mediator twice due to cache clear
      verify(mockMediator.send<GetSettingQuery, Setting?>(any)).called(2);
    });
  });

  group('DefaultTaskSettingsService Tests - Combined Caching', () {
    test('should cache estimated time and reminder settings independently', () async {
      // Arrange
      final estimatedTimeSetting = Setting(
        id: 'estimated-time-id',
        key: SettingKeys.taskDefaultEstimatedTime,
        value: '60',
        valueType: SettingValueType.int,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      final reminderSetting = Setting(
        id: 'reminder-id',
        key: SettingKeys.taskDefaultPlannedDateReminder,
        value: ReminderTime.fiveMinutesBefore.name,
        valueType: SettingValueType.string,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      // Setup different responses for different queries
      when(mockMediator.send<GetSettingQuery, Setting?>(captureThat(
        predicate<GetSettingQuery>((q) => q.key == SettingKeys.taskDefaultEstimatedTime),
      ))).thenAnswer((_) async => estimatedTimeSetting);

      when(mockMediator.send<GetSettingQuery, Setting?>(captureThat(
        predicate<GetSettingQuery>((q) => q.key == SettingKeys.taskDefaultPlannedDateReminder),
      ))).thenAnswer((_) async => reminderSetting);

      // Act
      await service.getDefaultEstimatedTime();
      await service.getDefaultPlannedDateReminder();
      await service.getDefaultEstimatedTime();
      await service.getDefaultPlannedDateReminder();

      // Assert - Each should be called exactly once (cached independently)
      verify(mockMediator.send<GetSettingQuery, Setting?>(captureThat(
        predicate<GetSettingQuery>((q) => q.key == SettingKeys.taskDefaultEstimatedTime),
      ))).called(1);

      verify(mockMediator.send<GetSettingQuery, Setting?>(captureThat(
        predicate<GetSettingQuery>((q) => q.key == SettingKeys.taskDefaultPlannedDateReminder),
      ))).called(1);
    });

    test('should clear all caches when clearCache is called', () async {
      // Arrange
      final estimatedTimeSetting = Setting(
        id: 'estimated-time-id',
        key: SettingKeys.taskDefaultEstimatedTime,
        value: '30',
        valueType: SettingValueType.int,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      final reminderSetting = Setting(
        id: 'reminder-id',
        key: SettingKeys.taskDefaultPlannedDateReminder,
        value: ReminderTime.fiveMinutesBefore.name,
        valueType: SettingValueType.string,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      // Setup different responses for different queries
      when(mockMediator.send<GetSettingQuery, Setting?>(captureThat(
        predicate<GetSettingQuery>((q) => q.key == SettingKeys.taskDefaultEstimatedTime),
      ))).thenAnswer((_) async => estimatedTimeSetting);

      when(mockMediator.send<GetSettingQuery, Setting?>(captureThat(
        predicate<GetSettingQuery>((q) => q.key == SettingKeys.taskDefaultPlannedDateReminder),
      ))).thenAnswer((_) async => reminderSetting);

      // Act - Load both, clear cache, then load both again
      await service.getDefaultEstimatedTime();
      await service.getDefaultPlannedDateReminder();
      service.clearCache();
      await service.getDefaultEstimatedTime();
      await service.getDefaultPlannedDateReminder();

      // Assert - Each should be called exactly twice (once before clear, once after)
      verify(mockMediator.send<GetSettingQuery, Setting?>(captureThat(
        predicate<GetSettingQuery>((q) => q.key == SettingKeys.taskDefaultEstimatedTime),
      ))).called(2);

      verify(mockMediator.send<GetSettingQuery, Setting?>(captureThat(
        predicate<GetSettingQuery>((q) => q.key == SettingKeys.taskDefaultPlannedDateReminder),
      ))).called(2);
    });
  });
}
