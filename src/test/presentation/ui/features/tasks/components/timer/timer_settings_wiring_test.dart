import 'package:acore/acore.dart' hide Container;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/shared/services/abstraction/i_timer_session_service.dart';
import 'package:whph/core/application/shared/services/timer_session_service.dart';
import 'package:whph/core/domain/shared/constants/app_assets.dart';
import 'package:whph/infrastructure/shared/features/wakelock/abstractions/i_wakelock_service.dart';
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/tasks/components/timer/timer.dart';
import 'package:whph/presentation/ui/features/tasks/components/timer_settings_dialog.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_reminder_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/notification_payload_service.dart';

/// Covers the parent side of the timer settings dialog: AppTimer's `_handleSettingsChanged` and the values the
/// next dialog is seeded from. Uses the real AppTimer, TimerController and TimerSessionService.

const _sessionId = 'task:settings-wiring';

/// Settings are never stored, so the controller starts from its defaults (pomodoro, work 25 min).
class _RecordingMediator extends Fake implements Mediator {
  final List<SaveSettingCommand> saved = [];

  @override
  Future<R> send<T extends IRequest<R>, R extends Object?>(T request) async {
    final Object message = request;
    if (message is SaveSettingCommand) {
      saved.add(message);
      return SaveSettingCommandResponse(id: 'id', createdDate: DateTime.utc(2026)) as R;
    }
    return null as R;
  }
}

class _FakeContainer extends Fake implements IContainer {
  final Map<Type, Object> _registrations = {};

  void register<T extends Object>(T instance) => _registrations[T] = instance;

  @override
  T resolve<T>([String? name]) => _registrations[T] as T;
}

class _FakeDurationWriter implements ITimerSessionDurationWriter {
  @override
  Future<void> write(TimerSessionDuration duration) async {}
}

class _FakeAlarmScheduler implements ITimerSessionAlarmScheduler {
  @override
  Future<void> cancel(String alarmId) async {}

  @override
  Future<void> schedule({required String alarmId, required DateTime scheduledAt}) async {}
}

class _FakeSoundManager extends Fake implements ISoundManagerService {
  @override
  void clearSettingsCache() {}

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> stopTimerAlarmLoop() async {}
}

class _FakeSystemTray extends Fake implements ISystemTrayService {
  @override
  Future<void> setTitle(String title) async {}

  @override
  Future<void> setBody(String body) async {}

  @override
  Future<void> setIcon(TrayIconType type) async {}

  @override
  Future<void> insertMenuItem(TrayMenuItem item, {int? index}) async {}

  @override
  Future<void> removeMenuItem(String key) async {}

  @override
  Future<void> reset() async {}

  @override
  List<TrayMenuItem> getMenuItems() => const [];
}

class _FakeWakelock extends Fake implements IWakelockService {
  @override
  Future<void> disable() async {}
}

class _FakeTranslation extends Fake implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
}

class _FakeNotification extends Fake implements INotificationService {}

class _FakeReminder extends Fake implements IReminderService {}

/// Counts `create` calls: TimerController.updateSettings re-initializes the shared session, so a rise in this
/// count after AppTimer is gone means the dismiss flush reached the disposed controller.
class _CountingSessionService extends TimerSessionService {
  int createCalls = 0;

  _CountingSessionService()
      : super(durationWriter: _FakeDurationWriter(), alarmScheduler: _FakeAlarmScheduler(), now: DateTime.now);

  @override
  TimerSessionState create({
    required String sessionId,
    required TimerSessionOwner owner,
    required TimerSessionSettings settings,
    String? selectedTaskId,
  }) {
    createCalls++;
    return super.create(sessionId: sessionId, owner: owner, settings: settings, selectedTaskId: selectedTaskId);
  }
}

void main() {
  late _RecordingMediator mediator;
  late _CountingSessionService sessionService;

  setUp(() {
    mediator = _RecordingMediator();
    sessionService = _CountingSessionService();
    app_main.container = _FakeContainer()
      ..register<Mediator>(mediator)
      ..register<ISoundManagerService>(_FakeSoundManager())
      ..register<ISystemTrayService>(_FakeSystemTray())
      ..register<ITranslationService>(_FakeTranslation())
      ..register<INotificationService>(_FakeNotification())
      ..register<IWakelockService>(_FakeWakelock())
      ..register<IReminderService>(_FakeReminder())
      ..register<ITimerSessionService>(sessionService);
  });

  tearDown(() async {
    NotificationPayloadService.disposeActionStream();
    await sessionService.shutdown();
  });

  Future<void> pumpTimer(WidgetTester tester, {Size size = const Size(1200, 1400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppTimer(sessionId: _sessionId, sessionOwner: TimerSessionOwner.task('settings-wiring')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byIcon(SharedUiConstants.settingsIcon));
    await tester.pumpAndSettle();
    expect(find.byType(TimerSettingsDialog), findsOneWidget);
  }

  Future<void> bumpWork(WidgetTester tester) async {
    final workRow = find.ancestor(of: find.text(TaskTranslationKeys.pomodoroWorkLabel), matching: find.byType(Row));
    await tester.tap(find.descendant(of: workRow.first, matching: find.byIcon(Icons.add)));
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1)); // post-frame parent notification
  }

  Duration sessionWorkDuration() => sessionService.state(_sessionId)!.settings.workDuration;

  final tickingLabel = TaskTranslationKeys.pomodoroTickingSoundLabel;

  Future<void> toggleTicking(WidgetTester tester) async {
    final row = find.widgetWithText(SwitchListTile, tickingLabel);
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump();
  }

  // The next dialog is seeded from TimerController.tickingEnabled etc., so its switch shows what the parent
  // holds after _handleSettingsChanged ran.
  bool tickingShownInDialog(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, tickingLabel)).value;

  Future<void> dismiss(WidgetTester tester, String via) async {
    switch (via) {
      case 'Esc':
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      case 'Done':
        await tester.tap(find.text(SharedTranslationKeys.doneButton));
      default:
        await tester.tapAt(const Offset(10, 5)); // barrier / sheet scrim
    }
    await settle(tester);
    expect(find.byType(TimerSettingsDialog), findsNothing);
  }

  for (final via in ['Esc', 'Done']) {
    testWidgets('after $via the parent holds the new values and the next dialog is seeded with them', (tester) async {
      await pumpTimer(tester);
      await openSettings(tester);
      expect(tickingShownInDialog(tester), isFalse);
      await toggleTicking(tester);
      await dismiss(tester, via);

      expect(mediator.saved.where((c) => c.key == SettingKeys.tickingEnabled).map((c) => c.value), ['true']);
      await openSettings(tester);
      expect(tickingShownInDialog(tester), isTrue);
    });
  }

  for (final via in ['Esc', 'Done']) {
    testWidgets('after $via the parent holds the new values and the next dialog is seeded with them', (tester) async {
      await pumpTimer(tester);
      await openSettings(tester);
      expect(tickingShownInDialog(tester), isFalse);
      await toggleTicking(tester);
      await dismiss(tester, via);

      expect(mediator.saved.where((c) => c.key == SettingKeys.tickingEnabled).map((c) => c.value), ['true']);
      await openSettings(tester);
      expect(tickingShownInDialog(tester), isTrue);
    });
  }

  // BLOCKED by a bug outside this change: TimerController.updateSettings (session path) applies the new values,
  // then _initializeSharedSession() -> _applySharedState(existing session) reverts the duration/mode/auto-start
  // fields to the stale session settings, so the next dialog shows the old value. Remove `skip` once fixed.
  for (final via in ['Esc', 'Done']) {
    testWidgets('after $via the next dialog is seeded with the new work duration', (tester) async {
      await pumpTimer(tester);
      await openSettings(tester);
      await bumpWork(tester);
      await dismiss(tester, via);

      expect(sessionWorkDuration(), const Duration(minutes: 30));
      await openSettings(tester);
      expect(find.descendant(of: find.byType(TimerSettingsDialog), matching: find.text('30')), findsOneWidget);
    });
  }

  testWidgets('dismissing the dialog with no change does not re-initialize the parent timer', (tester) async {
    await pumpTimer(tester);
    final createsBefore = sessionService.createCalls;
    await openSettings(tester);

    await dismiss(tester, 'Esc');

    expect(mediator.saved, isEmpty);
    expect(sessionService.createCalls, createsBefore);
  });

  testWidgets('a dismiss flush that finds the AppTimer already disposed does not touch the controller', (tester) async {
    await pumpTimer(tester);
    await openSettings(tester);
    await toggleTicking(tester);
    final createsBefore = sessionService.createCalls;

    // Parent and dialog are unmounted in the same frame; the dialog's post-frame notify then finds a dead parent.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    // Still persisted, but never applied: applying would re-initialize the shared session via the controller.
    expect(mediator.saved.where((c) => c.key == SettingKeys.tickingEnabled).map((c) => c.value), ['true']);
    expect(sessionService.createCalls, createsBefore);
  });

  // Production opens the dialog through ResponsiveDialogHelper: a bottom sheet on mobile. The test font is wider
  // than the real one and overflows the rows at phone widths, so force the mobile branch on a wide window.
  testWidgets('bottom sheet (mobile branch): barrier dismissal saves and applies the change', (tester) async {
    ResponsiveDialogHelper.configure(ResponsiveDialogConfig(isDesktopScreen: (_) => false));
    addTearDown(() => ResponsiveDialogHelper.configure(const ResponsiveDialogConfig()));
    await pumpTimer(tester);
    await openSettings(tester);
    expect(find.byType(Dialog), findsNothing); // a sheet, not the desktop dialog
    await toggleTicking(tester);

    await dismiss(tester, 'barrier');

    expect(mediator.saved.where((c) => c.key == SettingKeys.tickingEnabled).map((c) => c.value), ['true']);
    await openSettings(tester);
    expect(tickingShownInDialog(tester), isTrue);
  });
}
