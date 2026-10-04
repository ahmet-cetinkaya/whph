import 'dart:async';

import 'package:acore/acore.dart' hide Container;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/tasks/components/timer_settings_dialog.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/enums/timer_mode.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class _FakeTranslationService extends Fake implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
}

class _FakeSoundManager extends Fake implements ISoundManagerService {
  int clearSettingsCacheCalls = 0;

  @override
  void clearSettingsCache() => clearSettingsCacheCalls++;
}

// Failure tests log error stack traces on purpose: the dialog reports save failures via Logger.error.
class _FakeMediator extends Fake implements Mediator {
  final List<SaveSettingCommand> attempts = [];
  final List<SaveSettingCommand> saved = [];
  int failuresLeft = 0;
  bool failAlways = false;

  /// When set, the first send waits for this completer (an in-flight save).
  Completer<void>? firstSendGate;

  Iterable<String> savedKeys() => saved.map((c) => c.key);

  Iterable<String> savedValues(String key) => saved.where((c) => c.key == key).map((c) => c.value);

  @override
  Future<R> send<T extends IRequest<R>, R extends Object?>(T request) async {
    final command = request as SaveSettingCommand;
    attempts.add(command);
    final gate = firstSendGate;
    if (gate != null && attempts.length == 1) await gate.future;
    if (failAlways || failuresLeft > 0) {
      if (failuresLeft > 0) failuresLeft--;
      throw StateError('save failed');
    }
    saved.add(command);
    return SaveSettingCommandResponse(id: 'id', createdDate: DateTime.utc(2026)) as R;
  }
}

class _FakeContainer extends Fake implements IContainer {
  final Map<Type, Object> _registrations = {};

  void register<T extends Object>(T instance) => _registrations[T] = instance;

  void unregisterAll() => _registrations.clear();

  @override
  T resolve<T>([String? name]) {
    final registration = _registrations[T];
    if (registration == null) throw StateError('Service not registered: $T');
    return registration as T;
  }
}

class _Notification {
  final int workDuration;
  final int breakDuration;
  _Notification(this.workDuration, this.breakDuration);
}

void main() {
  late _FakeContainer container;
  late _FakeMediator mediator;
  late _FakeSoundManager soundManager;
  late List<_Notification> notifications;

  setUpAll(() {
    container = _FakeContainer();
    app_main.container = container;
  });

  setUp(() {
    mediator = _FakeMediator();
    soundManager = _FakeSoundManager();
    notifications = [];
    container.register<Mediator>(mediator);
    container.register<ITranslationService>(_FakeTranslationService());
    container.register<ISoundManagerService>(soundManager);
  });

  // app_main.container is a late global and cannot be unset; empty the fake so nothing leaks between tests.
  tearDown(() => container.unregisterAll());

  // Finders anchored on the (key-echoing) labels instead of widget order.
  Finder plusOf(String label) => find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
        matching: find.byIcon(Icons.add),
      );
  Finder switchOf(String label) => find.widgetWithText(SwitchListTile, label);
  final doneButton = find.text(SharedTranslationKeys.doneButton);

  TimerSettingsDialog buildDialog({int work = 25}) => TimerSettingsDialog(
        initialTimerMode: TimerMode.pomodoro,
        initialWorkDuration: work,
        initialBreakDuration: 5,
        initialLongBreakDuration: 15,
        initialSessionsCount: 4,
        initialAutoStartBreak: false,
        initialAutoStartWork: false,
        initialTickingEnabled: false,
        initialKeepScreenAwake: false,
        initialTickingVolume: 50,
        initialTickingSpeed: 3,
        onSettingsChanged:
            (mode, work, brk, longBrk, sessions, autoBreak, autoWork, ticking, awake, volume, speed) async {
          notifications.add(_Notification(work, brk));
        },
      );

  /// Opens the dialog in a real dialog route so barrier/Esc dismissal is exercised.
  Future<void> openDialog(WidgetTester tester, {int work = 25}) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => Center(child: SizedBox(width: 900, height: 1200, child: buildDialog(work: work))),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> bumpWork(WidgetTester tester) async {
    await tester.tap(plusOf(TaskTranslationKeys.pomodoroWorkLabel));
    await tester.pump();
  }

  Future<void> bumpBreak(WidgetTester tester) async {
    await tester.tap(plusOf(TaskTranslationKeys.pomodoroBreakLabel));
    await tester.pump();
  }

  testWidgets('(a) a change disposed before the debounce fires is still saved', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: buildDialog()));
    await bumpWork(tester);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    expect(mediator.savedValues(SettingKeys.workTime), ['30']);
  });

  testWidgets('(b) Done saves once and notifies the parent once', (tester) async {
    await openDialog(tester);
    await bumpWork(tester);

    await tester.tap(doneButton);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    expect(mediator.savedValues(SettingKeys.workTime), ['30']);
    expect(notifications, hasLength(1));
    expect(notifications.single.workDuration, 30);
    expect(find.byType(TimerSettingsDialog), findsNothing);
  });

  testWidgets('(c) a failed first save is retried when the dialog is closed', (tester) async {
    await openDialog(tester);
    mediator.failuresLeft = 1;
    await bumpWork(tester);
    await tester.pump(TimerSettingsDialog.saveDebounce + const Duration(milliseconds: 100));
    expect(mediator.saved, isEmpty);

    await tester.tap(doneButton);
    await tester.pumpAndSettle();

    expect(mediator.savedValues(SettingKeys.workTime), ['30']);
    expect(notifications, hasLength(1));
  });

  testWidgets('(d) a key added while a save is in flight is not lost', (tester) async {
    await openDialog(tester);
    mediator.firstSendGate = Completer<void>();
    await bumpWork(tester);
    await tester.pump(TimerSettingsDialog.saveDebounce + const Duration(milliseconds: 100)); // work save now in flight
    await bumpBreak(tester);

    mediator.firstSendGate!.complete();
    await tester.pump();

    await tester.tap(doneButton);
    await tester.pumpAndSettle();

    expect(mediator.savedValues(SettingKeys.workTime), ['30']);
    expect(mediator.savedValues(SettingKeys.breakTime), ['10']);
  });

  for (final viaEscape in [true, false]) {
    testWidgets('(e) dismiss via ${viaEscape ? 'Esc' : 'barrier'} notifies the parent once with the new values',
        (tester) async {
      await openDialog(tester);
      await bumpWork(tester);

      if (viaEscape) {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      } else {
        await tester.tapAt(const Offset(5, 5));
      }
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(TimerSettingsDialog), findsNothing);
      expect(mediator.savedValues(SettingKeys.workTime), ['30']);
      expect(notifications, hasLength(1));
      expect(notifications.single.workDuration, 30);
      // Seeding of the next dialog from the parent state is covered in timer_settings_wiring_test.dart.
    });
  }

  testWidgets('(f) a failed save on Done still pops', (tester) async {
    await openDialog(tester);
    mediator.failAlways = true;
    await bumpWork(tester);

    await tester.tap(doneButton);
    await tester.pumpAndSettle();

    expect(find.byType(TimerSettingsDialog), findsNothing);
    // Pins "retry once": the Done attempt plus a single retry from the dispose flush.
    expect(mediator.attempts, hasLength(2));
  });

  testWidgets('dismissing without changes does not notify the parent', (tester) async {
    await openDialog(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    expect(mediator.attempts, isEmpty);
    expect(notifications, isEmpty);
  });

  for (final viaBack in [false, true]) {
    testWidgets('${viaBack ? 'back arrow' : 'Done'} without changes pops without notifying the parent', (tester) async {
      await openDialog(tester);

      await tester.tap(viaBack ? find.byIcon(Icons.arrow_back) : doneButton);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(TimerSettingsDialog), findsNothing);
      expect(mediator.attempts, isEmpty);
      expect(notifications, isEmpty);
    });
  }

  testWidgets('a bool setting is saved as bool and clears the sound settings cache', (tester) async {
    await openDialog(tester);
    await tester.tap(switchOf(TaskTranslationKeys.pomodoroTickingSoundLabel));
    await tester.pump();

    await tester.tap(doneButton);
    await tester.pumpAndSettle();

    final command = mediator.saved.single;
    expect(command.key, SettingKeys.tickingEnabled);
    expect(command.value, 'true');
    expect(command.valueType, SettingValueType.bool);
    expect(soundManager.clearSettingsCacheCalls, 1);
  });

  testWidgets('several pending keys are all saved', (tester) async {
    await openDialog(tester);
    await bumpWork(tester);
    await bumpBreak(tester);
    await tester.tap(switchOf(TaskTranslationKeys.pomodoroAutoStartBreakLabel));
    await tester.pump();

    await tester.tap(doneButton);
    await tester.pumpAndSettle();

    expect(mediator.savedKeys(),
        unorderedEquals([SettingKeys.workTime, SettingKeys.breakTime, SettingKeys.autoStartBreak]));
    expect(mediator.savedValues(SettingKeys.autoStartBreak), ['true']);
    expect(notifications, hasLength(1));
  });

  testWidgets('the timer mode tab saves the mode as a string and notifies the parent right away', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text(SharedTranslationKeys.normalTimer));
    await tester.pumpAndSettle();

    final command = mediator.saved.single;
    expect(command.key, SettingKeys.defaultTimerMode);
    expect(command.value, TimerMode.normal.value);
    expect(command.valueType, SettingValueType.string);
    expect(notifications, hasLength(1));
  });

  testWidgets('a failed timer mode save is retried when the dialog is closed', (tester) async {
    await openDialog(tester);
    mediator.failuresLeft = 1;

    await tester.tap(find.text(SharedTranslationKeys.normalTimer));
    await tester.pumpAndSettle();
    expect(mediator.saved, isEmpty);
    expect(notifications, hasLength(1)); // the parent still gets the in-memory mode

    await tester.tap(doneButton);
    await tester.pumpAndSettle();

    expect(mediator.savedValues(SettingKeys.defaultTimerMode), [TimerMode.normal.value]);
  });

  testWidgets('a failed timer mode save is retried when the dialog is dismissed', (tester) async {
    await openDialog(tester);
    mediator.failuresLeft = 1;

    await tester.tap(find.text(SharedTranslationKeys.normalTimer));
    await tester.pumpAndSettle();
    expect(mediator.saved, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(mediator.savedValues(SettingKeys.defaultTimerMode), [TimerMode.normal.value]);
  });

  testWidgets('dismissing while a save is in flight queues the flush behind it, in order', (tester) async {
    await openDialog(tester);
    mediator.firstSendGate = Completer<void>();
    await bumpWork(tester);
    await tester.pump(TimerSettingsDialog.saveDebounce + const Duration(milliseconds: 100)); // work save in flight
    await bumpBreak(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // route transition ends, dialog is disposed
    expect(find.byType(TimerSettingsDialog), findsNothing);
    // The dispose flush must not start a second send while the first is still pending.
    expect(mediator.attempts, hasLength(1));

    mediator.firstSendGate!.complete();
    await tester.pumpAndSettle();

    expect(mediator.savedKeys(), [SettingKeys.workTime, SettingKeys.breakTime]);
  });
}
