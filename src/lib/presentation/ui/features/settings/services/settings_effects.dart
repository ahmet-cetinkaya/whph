import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:whph/core/application/features/settings/models/public_setting.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_settings_effects.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/application/shared/services/abstraction/i_timer_session_service.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/features/notifications/services/reminder_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/background_translation_service.dart';

final class SettingsEffects implements ISettingsEffects {
  final IThemeService _themeService;
  final ISoundManagerService _soundManagerService;
  final HabitsService _habitsService;
  final ReminderService _reminderService;
  final ISettingRepository _settingRepository;
  final ITimerSessionService _timerSessionService;
  final GlobalKey<NavigatorState> _navigatorKey;

  const SettingsEffects({
    required IThemeService themeService,
    required ISoundManagerService soundManagerService,
    required HabitsService habitsService,
    required ReminderService reminderService,
    required ISettingRepository settingRepository,
    required ITimerSessionService timerSessionService,
    required GlobalKey<NavigatorState> navigatorKey,
  })  : _themeService = themeService,
        _soundManagerService = soundManagerService,
        _habitsService = habitsService,
        _reminderService = reminderService,
        _settingRepository = settingRepository,
        _timerSessionService = timerSessionService,
        _navigatorKey = navigatorKey;

  @override
  Future<void> apply(PublicSettingChange change) async {
    switch (change.key) {
      case PublicSettingKey.themeMode:
      case PublicSettingKey.dynamicAccentEnabled:
      case PublicSettingKey.customAccentArgb:
      case PublicSettingKey.uiDensity:
        await _themeService.refreshTheme();
      case PublicSettingKey.language:
        await _applyLanguage(change.value as String);
      case PublicSettingKey.soundEnabled:
      case PublicSettingKey.taskCompletionSoundEnabled:
      case PublicSettingKey.habitCompletionSoundEnabled:
      case PublicSettingKey.timerControlSoundEnabled:
      case PublicSettingKey.timerAlarmSoundEnabled:
      case PublicSettingKey.tickingEnabled:
      case PublicSettingKey.tickingVolume:
      case PublicSettingKey.tickingSpeed:
        _soundManagerService.clearSettingsCache();
      case PublicSettingKey.habitThreeStateEnabled:
      case PublicSettingKey.habitReverseDayOrder:
        _habitsService.notifySettingsChanged();
      case PublicSettingKey.notificationsEnabled:
        return;
      case PublicSettingKey.workMinutes:
      case PublicSettingKey.breakMinutes:
      case PublicSettingKey.longBreakMinutes:
      case PublicSettingKey.sessionsBeforeLongBreak:
      case PublicSettingKey.autoStartBreak:
      case PublicSettingKey.autoStartWork:
        await _refreshTimerSessions();
      case PublicSettingKey.keepScreenAwake:
      case PublicSettingKey.defaultTimerMode:
      case PublicSettingKey.defaultPage:
      case PublicSettingKey.taskDefaultEstimatedMinutes:
      case PublicSettingKey.taskDefaultPlannedReminder:
      case PublicSettingKey.taskDefaultPlannedReminderCustomOffsetMinutes:
      case PublicSettingKey.taskSkipQuickAdd:
        return;
    }
  }

  Future<void> _applyLanguage(String languageCode) async {
    final context = _navigatorKey.currentContext;
    if (context != null && context.mounted) {
      await context.setLocale(Locale(languageCode));
    }
    await BackgroundTranslationService().initialize();
    await _reminderService.refreshAllRemindersForLanguageChange();
  }

  Future<void> _refreshTimerSessions() async {
    final workMinutes = await _readInt(PublicSettingKey.workMinutes);
    final breakMinutes = await _readInt(PublicSettingKey.breakMinutes);
    final longBreakMinutes = await _readInt(PublicSettingKey.longBreakMinutes);
    final sessionsBeforeLongBreak = await _readInt(PublicSettingKey.sessionsBeforeLongBreak);
    final autoStartBreak = await _readBool(PublicSettingKey.autoStartBreak);
    final autoStartWork = await _readBool(PublicSettingKey.autoStartWork);

    for (final session in _timerSessionService.list()) {
      await _timerSessionService.updateSettings(
        session.sessionId,
        TimerSessionSettings(
          mode: session.settings.mode,
          workDuration: Duration(minutes: workMinutes),
          breakDuration: Duration(minutes: breakMinutes),
          longBreakDuration: Duration(minutes: longBreakMinutes),
          sessionsBeforeLongBreak: sessionsBeforeLongBreak,
          autoStartBreak: autoStartBreak,
          autoStartWork: autoStartWork,
        ),
      );
    }
  }

  Future<int> _readInt(PublicSettingKey key) async => (await _read(key)) as int;

  Future<bool> _readBool(PublicSettingKey key) async => (await _read(key)) as bool;

  Future<Object?> _read(PublicSettingKey key) async {
    final setting = await _settingRepository.getByKey(key.storageKey);
    return setting == null ? key.defaultValue : key.decode(setting.value);
  }
}
