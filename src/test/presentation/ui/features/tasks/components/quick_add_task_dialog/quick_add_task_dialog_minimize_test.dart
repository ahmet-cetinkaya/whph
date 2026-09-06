import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/features/tasks/components/quick_add_task_dialog/components/quick_action_buttons_bar.dart';
import 'package:whph/presentation/ui/features/tasks/components/quick_add_task_dialog/minimizable_routes.dart';
import 'package:whph/presentation/ui/features/tasks/components/quick_add_task_dialog/quick_add_task_dialog.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'quick_add_task_dialog_test_doubles.dart';

void main() {
  setUpAll(installFakeContainer);

  setUp(() => AppTheme.resetService());

  /// Pumps the real [QuickAddTaskDialog] inside a [SheetMinimizeScope], which is
  /// exactly how the mobile route hosts it. No production logic is reimplemented.
  Future<void> pumpDialog(
    WidgetTester tester,
    SheetMinimizeController minimizeController,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SheetMinimizeScope(
              controller: minimizeController,
              child: const QuickAddTaskDialog(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('QuickAddTaskDialog minimize/restore', () {
    testWidgets('preserves typed title and dialog state across minimize and restore',
        (WidgetTester tester) async {
      final minimizeController = SheetMinimizeController();
      addTearDown(minimizeController.dispose);

      await pumpDialog(tester, minimizeController);

      await tester.enterText(find.byType(TextField).first, 'Buy milk');
      await tester.pumpAndSettle();

      expect(find.text('Buy milk'), findsOneWidget);
      expect(find.byType(QuickActionButtonsBar), findsOneWidget);

      final stateBeforeMinimize = tester.state(find.byType(QuickAddTaskDialog));

      await tester.tap(find.byTooltip(TaskTranslationKeys.quickTaskMinimize));
      await tester.pumpAndSettle();

      expect(minimizeController.isMinimized, isTrue);
      expect(find.byTooltip(TaskTranslationKeys.quickTaskRestore), findsOneWidget);

      await tester.tap(find.byTooltip(TaskTranslationKeys.quickTaskRestore));
      await tester.pumpAndSettle();

      expect(minimizeController.isMinimized, isFalse);

      // Regression guard: the State was never recreated, so no input was lost.
      expect(tester.state(find.byType(QuickAddTaskDialog)), same(stateBeforeMinimize));
      expect(find.text('Buy milk'), findsOneWidget);
      expect(find.byType(QuickActionButtonsBar), findsOneWidget);
    });

    testWidgets('keeps the action bar mounted while minimized', (WidgetTester tester) async {
      final minimizeController = SheetMinimizeController();
      addTearDown(minimizeController.dispose);

      await pumpDialog(tester, minimizeController);

      await tester.tap(find.byTooltip(TaskTranslationKeys.quickTaskMinimize));
      await tester.pumpAndSettle();

      // Offstage (rather than removal) is what makes state survival structural.
      expect(find.byType(QuickActionButtonsBar, skipOffstage: false), findsOneWidget);
      expect(find.byType(QuickActionButtonsBar), findsNothing);
    });

    testWidgets('hides the minimize affordance when no SheetMinimizeScope is present',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: QuickAddTaskDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Desktop hosts the dialog without the scope; the button must not appear.
      expect(find.byTooltip(TaskTranslationKeys.quickTaskMinimize), findsNothing);
    });
  });
}
