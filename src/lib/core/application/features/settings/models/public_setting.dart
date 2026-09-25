import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';

enum PublicSettingKey {
  themeMode('themeMode', SettingKeys.themeMode, 'string', 'auto'),
  dynamicAccentEnabled('dynamicAccentEnabled', SettingKeys.dynamicAccentColor, 'boolean', false),
  customAccentArgb('customAccentArgb', SettingKeys.customAccentColor, 'nullable_integer', null),
  uiDensity('uiDensity', SettingKeys.uiDensity, 'string', 'system'),
  language('language', SettingKeys.currentLocale, 'string', 'en'),
  notificationsEnabled('notificationsEnabled', SettingKeys.notifications, 'boolean', true),
  soundEnabled('soundEnabled', SettingKeys.soundEnabled, 'boolean', true),
  taskCompletionSoundEnabled('taskCompletionSoundEnabled', SettingKeys.taskCompletionSoundEnabled, 'boolean', true),
  habitCompletionSoundEnabled('habitCompletionSoundEnabled', SettingKeys.habitCompletionSoundEnabled, 'boolean', true),
  timerControlSoundEnabled('timerControlSoundEnabled', SettingKeys.timerControlSoundEnabled, 'boolean', true),
  timerAlarmSoundEnabled('timerAlarmSoundEnabled', SettingKeys.timerAlarmSoundEnabled, 'boolean', true),
  workMinutes('workMinutes', SettingKeys.workTime, 'integer', 25),
  breakMinutes('breakMinutes', SettingKeys.breakTime, 'integer', 5),
  longBreakMinutes('longBreakMinutes', SettingKeys.longBreakTime, 'integer', 15),
  sessionsBeforeLongBreak('sessionsBeforeLongBreak', SettingKeys.sessionsBeforeLongBreak, 'integer', 4),
  autoStartBreak('autoStartBreak', SettingKeys.autoStartBreak, 'boolean', false),
  autoStartWork('autoStartWork', SettingKeys.autoStartWork, 'boolean', false),
  tickingEnabled('tickingEnabled', SettingKeys.tickingEnabled, 'boolean', false),
  tickingVolume('tickingVolume', SettingKeys.tickingVolume, 'integer', 50),
  tickingSpeed('tickingSpeed', SettingKeys.tickingSpeed, 'integer', 1),
  keepScreenAwake('keepScreenAwake', SettingKeys.keepScreenAwake, 'boolean', false),
  defaultTimerMode('defaultTimerMode', SettingKeys.defaultTimerMode, 'string', 'pomodoro'),
  defaultPage('defaultPage', SettingKeys.defaultPage, 'string', '/today'),
  taskDefaultEstimatedMinutes('taskDefaultEstimatedMinutes', SettingKeys.taskDefaultEstimatedTime, 'integer', 0),
  taskDefaultPlannedReminder(
      'taskDefaultPlannedReminder', SettingKeys.taskDefaultPlannedDateReminder, 'string', 'none'),
  taskDefaultPlannedReminderCustomOffsetMinutes('taskDefaultPlannedReminderCustomOffsetMinutes',
      SettingKeys.taskDefaultPlannedDateReminderCustomOffset, 'integer', 0),
  taskSkipQuickAdd('taskSkipQuickAdd', SettingKeys.taskSkipQuickAdd, 'boolean', false),
  habitThreeStateEnabled('habitThreeStateEnabled', SettingKeys.habitThreeStateEnabled, 'boolean', false),
  habitReverseDayOrder('habitReverseDayOrder', SettingKeys.habitReverseDayOrder, 'boolean', false);

  const PublicSettingKey(this.publicName, this.storageKey, this.valueType, this.defaultValue);

  final String publicName;
  final String storageKey;
  final String valueType;
  final Object? defaultValue;

  static PublicSettingKey? fromPublicName(String value) {
    for (final key in values) {
      if (key.publicName == value) return key;
    }
    return null;
  }

  SettingValueType get storageType => switch (valueType) {
        'boolean' => SettingValueType.bool,
        'integer' => SettingValueType.int,
        'nullable_integer' => SettingValueType.string,
        _ => SettingValueType.string,
      };

  Object? normalize(Object? value) => switch (this) {
        themeMode => _enum(value, const {'auto', 'light', 'dark'}),
        uiDensity => _enum(value, const {'system', 'compact', 'normal', 'large', 'larger'}),
        language => _enum(value, const {
            'cs',
            'da',
            'de',
            'el',
            'en',
            'es',
            'fi',
            'fr',
            'it',
            'ja',
            'ko',
            'nl',
            'no',
            'pl',
            'pt',
            'ro',
            'ru',
            'sl',
            'sv',
            'tr',
            'uk',
            'zh'
          }),
        defaultTimerMode => _enum(value, const {'pomodoro', 'normal', 'stopwatch'}),
        defaultPage => _enum(value, const {'/today', '/tasks', '/habits', '/notes', '/app-usages', '/tags'}),
        taskDefaultPlannedReminder => _enum(value, const {
            'none',
            'atTime',
            'fiveMinutesBefore',
            'fifteenMinutesBefore',
            'oneHourBefore',
            'oneDayBefore',
            'custom'
          }),
        workMinutes || breakMinutes || longBreakMinutes => _integer(value, 1, 120),
        sessionsBeforeLongBreak => _integer(value, 1, 10),
        tickingVolume => _integer(value, 5, 100),
        tickingSpeed => _integer(value, 1, 5),
        taskDefaultEstimatedMinutes => _integer(value, 0, 1440),
        taskDefaultPlannedReminderCustomOffsetMinutes => _integer(value, 0, 10080),
        customAccentArgb => value == null ? null : _integer(value, 0, 0xffffffff),
        _ => _boolean(value),
      };

  String encode(Object? value) => value?.toString() ?? '';

  Object? decode(String value) => switch (valueType) {
        'boolean' => value == 'true',
        'integer' => int.parse(value),
        'nullable_integer' => value.isEmpty ? null : int.parse(value),
        _ => value,
      };

  static String _enum(Object? value, Set<String> allowed) {
    if (value is String && allowed.contains(value)) return value;
    throw FormatException('Value must be one of: ${allowed.join(', ')}.');
  }

  static int _integer(Object? value, int minimum, int maximum) {
    if (value is int && value >= minimum && value <= maximum) return value;
    throw FormatException('Value must be an integer from $minimum through $maximum.');
  }

  static bool _boolean(Object? value) {
    if (value is bool) return value;
    throw const FormatException('Value must be a boolean.');
  }
}

final class PublicSettingRecord {
  const PublicSettingRecord({required this.key, required this.value, required this.revision});

  final PublicSettingKey key;
  final Object? value;
  final DateTime? revision;
}

final class PublicSettingChange {
  const PublicSettingChange({required this.key, required this.value});

  final PublicSettingKey key;
  final Object? value;
}
