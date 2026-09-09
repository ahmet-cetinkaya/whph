part of 'settings_tools.dart';

final _publicSettingNames = PublicSettingKey.values
    .map((key) => key.publicName)
    .toList(growable: false);

final JsonObject _settingsUpdateInputSchema = JsonObject.fromJson({
  'type': 'object',
  'properties': {
    'key': {'type': 'string', 'enum': _publicSettingNames},
    'value': {},
    'expectedRevision': {'type': 'string', 'format': 'date-time'},
  },
  'required': ['key', 'value'],
  'additionalProperties': false,
  'oneOf': PublicSettingKey.values.map(_settingVariantSchema).toList(),
});

Map<String, dynamic> _settingVariantSchema(PublicSettingKey key) => {
      'type': 'object',
      'properties': {
        'key': {'const': key.publicName},
        'value': _valueSchema(key),
        'expectedRevision': {'type': 'string', 'format': 'date-time'},
      },
      'required': ['key', 'value'],
      'additionalProperties': false,
    };

Map<String, dynamic> _valueSchema(PublicSettingKey key) => switch (key) {
      PublicSettingKey.themeMode => _enum(const ['auto', 'light', 'dark']),
      PublicSettingKey.uiDensity =>
        _enum(const ['system', 'compact', 'normal', 'large', 'larger']),
      PublicSettingKey.language => _enum(const [
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
        ]),
      PublicSettingKey.defaultTimerMode =>
        _enum(const ['pomodoro', 'normal', 'stopwatch']),
      PublicSettingKey.defaultPage => _enum(const [
          '/today',
          '/tasks',
          '/habits',
          '/notes',
          '/app-usages',
          '/tags'
        ]),
      PublicSettingKey.taskDefaultPlannedReminder => _enum(const [
          'none',
          'atTime',
          'fiveMinutesBefore',
          'fifteenMinutesBefore',
          'oneHourBefore',
          'oneDayBefore',
          'custom'
        ]),
      PublicSettingKey.workMinutes ||
      PublicSettingKey.breakMinutes ||
      PublicSettingKey.longBreakMinutes =>
        _integer(1, 120),
      PublicSettingKey.sessionsBeforeLongBreak => _integer(1, 10),
      PublicSettingKey.tickingVolume => _integer(5, 100),
      PublicSettingKey.tickingSpeed => _integer(1, 5),
      PublicSettingKey.taskDefaultEstimatedMinutes => _integer(0, 1440),
      PublicSettingKey.taskDefaultPlannedReminderCustomOffsetMinutes =>
        _integer(0, 10080),
      PublicSettingKey.customAccentArgb => {
          'oneOf': [
            {'type': 'integer', 'minimum': 0, 'maximum': 0xffffffff},
            {'type': 'null'},
          ]
        },
      _ => {'type': 'boolean'},
    };

Map<String, dynamic> _enum(List<String> values) =>
    {'type': 'string', 'enum': values};
Map<String, dynamic> _integer(int minimum, int maximum) =>
    {'type': 'integer', 'minimum': minimum, 'maximum': maximum};

final _settingOutputSchema = JsonSchema.object(
  properties: {
    'key': JsonSchema.string(),
    'value': JsonSchema.fromJson(const {}),
    'valueType': JsonSchema.string(),
    'revision': JsonSchema.string(),
  },
  required: const ['key', 'value', 'valueType'],
  additionalProperties: false,
);

final _settingsListOutputSchema = JsonSchema.object(
  properties: {'settings': JsonSchema.array(items: _settingOutputSchema)},
  required: const ['settings'],
  additionalProperties: false,
);

final _settingsUpdateOutputSchema = JsonSchema.object(
  properties: {
    'key': JsonSchema.string(),
    'value': JsonSchema.fromJson(const {}),
    'valueType': JsonSchema.string(),
    'revision': JsonSchema.string(),
    'committed': JsonSchema.boolean(),
    'effectStatus': JsonSchema.string(enumValues: const ['applied', 'failed']),
    'effectError': JsonSchema.string(),
  },
  required: const ['key', 'value', 'valueType', 'committed', 'effectStatus'],
  additionalProperties: false,
);

const _readAnnotations = ToolAnnotations(
    readOnlyHint: true,
    destructiveHint: false,
    idempotentHint: true,
    openWorldHint: false);
const _mutationAnnotations = ToolAnnotations(
    readOnlyHint: false,
    destructiveHint: true,
    idempotentHint: true,
    openWorldHint: false);
