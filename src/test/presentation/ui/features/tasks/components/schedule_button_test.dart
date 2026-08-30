import 'package:acore/acore.dart' hide Container;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' show UiDensity;
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/tasks/components/schedule_button.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/providers/drag_state_provider.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

const scheduleTooltip = 'Schedule task';

class FakeTranslationService extends Fake implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) =>
      key == TaskTranslationKeys.taskScheduleTooltip ? scheduleTooltip : key;
}

class FakeThemeService extends Fake implements IThemeService {
  @override
  Color get secondaryTextColor => Colors.grey;

  @override
  UiDensity get currentUiDensity => UiDensity.normal;
}

class FakeContainer extends Fake implements IContainer {
  final Map<Type, dynamic> _registrations = {};

  void register<T>(T instance) => _registrations[T] = instance;

  @override
  T resolve<T>([String? name]) => _registrations[T] as T;
}

void main() {
  setUp(() {
    app_main.container = FakeContainer()..register<IThemeService>(FakeThemeService());
  });

  testWidgets('uses a sliver-safe translated hover label and survives drag-state transitions', (tester) async {
    final dragState = DragStateNotifier();
    addTearDown(dragState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DragStateProvider(
            notifier: dragState,
            child: ScheduleButton(
              translationService: FakeTranslationService(),
              onScheduleSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    final frameworkTooltips = find.descendant(
      of: find.byType(ScheduleButton),
      matching: find.byType(Tooltip),
    );
    expect(frameworkTooltips, findsOneWidget);
    expect(
      tester.widget<Tooltip>(frameworkTooltips).message,
      isEmpty,
      reason: 'an empty framework Tooltip never builds the unsafe localToGlobal overlay',
    );
    expect(
      tester.widget<PopupMenuButton<ScheduleOption>>(find.byType(PopupMenuButton<ScheduleOption>)).tooltip,
      isEmpty,
      reason: 'PopupMenuButton must not create its own unsafe IconButton tooltip',
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    final buttonCenter = tester.getCenter(find.byType(PopupMenuButton<ScheduleOption>));
    await mouse.moveTo(buttonCenter);
    await tester.pump();

    expect(find.text(scheduleTooltip), findsOneWidget);

    dragState.startDragging();
    await tester.pump();
    expect(find.text(scheduleTooltip), findsNothing);
    dragState.stopDragging();
    await tester.pump();
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
