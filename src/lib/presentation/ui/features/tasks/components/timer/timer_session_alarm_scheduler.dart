import 'package:whph/core/application/shared/services/abstraction/i_timer_session_service.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_reminder_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class TimerSessionAlarmScheduler implements ITimerSessionAlarmScheduler {
  final IReminderService _reminderService;
  final ITranslationService _translationService;

  const TimerSessionAlarmScheduler({
    required IReminderService reminderService,
    required ITranslationService translationService,
  })  : _reminderService = reminderService,
        _translationService = translationService;

  @override
  Future<void> schedule({
    required String alarmId,
    required DateTime scheduledAt,
  }) =>
      _reminderService.scheduleReminder(
        id: alarmId,
        title: _translationService.translate(TaskTranslationKeys.pomodoroNotificationTitle),
        body: _translationService.translate(TaskTranslationKeys.pomodoroTimerCompleted),
        scheduledDate: scheduledAt,
      );

  @override
  Future<void> cancel(String alarmId) => _reminderService.cancelReminder(alarmId);
}
