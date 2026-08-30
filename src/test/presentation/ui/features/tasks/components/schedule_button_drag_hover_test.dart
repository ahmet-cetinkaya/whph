import 'package:acore/acore.dart' hide Container;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' show UiDensity;
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/tasks/components/schedule_button.dart';
import 'package:whph/presentation/ui/shared/providers/drag_state_provider.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class MockTranslationService extends Mock implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
}

class FakeThemeService extends Fake implements IThemeService {
  @override
  Color get secondaryTextColor => Colors.grey;

  @override
  UiDensity get currentUiDensity => UiDensity.normal;
}

class FakeContainer extends Fake implements IContainer {
  final Map<Type, dynamic> _registrations = {};

  void register<T>(dynamic instance) => _registrations[T] = instance;

  @override
  T resolve<T>([String? name]) => _registrations[T] as T;
}

void main() {
  setUp(() {
    final fakeContainer = FakeContainer()..register<IThemeService>(FakeThemeService());
    app_main.container = fakeContainer;
  });

  testWidgets('hover survives drag-state start and stop without throwing', (tester) async {
    final dragState = DragStateNotifier();
    addTearDown(dragState.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DragStateProvider(
          notifier: dragState,
          child: ScheduleButton(
            translationService: MockTranslationService(),
            onScheduleSelected: (_) {},
          ),
        ),
      ),
    ));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    final buttonCenter = tester.getCenter(find.byType(ScheduleButton));
    await mouse.moveTo(buttonCenter);
    await tester.pump(const Duration(seconds: 1));

    dragState.startDragging();
    await tester.pump();
    dragState.stopDragging();
    await tester.pump();
    await mouse.moveTo(buttonCenter + const Offset(1, 0));
    await tester.pump(const Duration(seconds: 1));
    dragState.startDragging();
    await tester.pump();
    dragState.stopDragging();
    await tester.pump();
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
