import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/features/tasks/components/quick_add_task_dialog/components/quick_action_buttons_bar.dart';
import 'package:whph/presentation/ui/features/tasks/components/quick_add_task_dialog/minimizable_routes.dart';
import 'package:whph/presentation/ui/features/tasks/components/quick_add_task_dialog/quick_add_task_dialog.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
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
    testWidgets('preserves typed title and dialog state across minimize and restore', (WidgetTester tester) async {
      final minimizeController = SheetMinimizeController(false);
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

    testWidgets('preserves a selected tag across minimize and restore', (WidgetTester tester) async {
      final minimizeController = SheetMinimizeController(false);
      addTearDown(minimizeController.dispose);

      await pumpDialog(tester, minimizeController);

      // The tag picker opens a full dialog; the default narrow sheet surface
      // overflows its action row and the tap would land on a clipped widget.
      await tester.binding.setSurfaceSize(const Size(900, 900));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(TagUiConstants.tagIcon).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(stubTagNames.first).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(SharedTranslationKeys.doneButton).last);
      await tester.pumpAndSettle();

      // The tooltip renders the selected tag names, so its presence proves the
      // dropdown really holds a selection - otherwise the assertion after the
      // cycle would pass vacuously.
      expect(find.byTooltip(stubTagNames.first), findsOneWidget);

      await tester.tap(find.byTooltip(TaskTranslationKeys.quickTaskMinimize));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(TaskTranslationKeys.quickTaskRestore));
      await tester.pumpAndSettle();

      expect(find.byTooltip(stubTagNames.first), findsOneWidget);
    });

    testWidgets('preserves a typed description across minimize and restore', (WidgetTester tester) async {
      final minimizeController = SheetMinimizeController(false);
      addTearDown(minimizeController.dispose);

      await pumpDialog(tester, minimizeController);

      await tester.tap(find.byIcon(Icons.description_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Two litres, semi-skimmed');
      await tester.pumpAndSettle();
      await tester.tap(find.text(SharedTranslationKeys.doneButton).last);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.description), findsOneWidget,
          reason: 'the description must actually be set, otherwise the assertion below is vacuous');

      await tester.tap(find.byTooltip(TaskTranslationKeys.quickTaskMinimize));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(TaskTranslationKeys.quickTaskRestore));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.description), findsOneWidget);
    });

    testWidgets('releases focus when minimized so the keyboard does not cover the page', (WidgetTester tester) async {
      final minimizeController = SheetMinimizeController(false);
      addTearDown(minimizeController.dispose);

      await pumpDialog(tester, minimizeController);

      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue, reason: 'the keyboard must be up before minimizing');

      await tester.tap(find.byTooltip(TaskTranslationKeys.quickTaskMinimize));
      await tester.pumpAndSettle();

      // A minimized sheet under an open keyboard would hide the page it just
      // uncovered, defeating the point of minimizing.
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('keeps the action bar mounted while minimized', (WidgetTester tester) async {
      final minimizeController = SheetMinimizeController(false);
      addTearDown(minimizeController.dispose);

      await pumpDialog(tester, minimizeController);

      await tester.tap(find.byTooltip(TaskTranslationKeys.quickTaskMinimize));
      await tester.pumpAndSettle();

      // Offstage (rather than removal) is what makes state survival structural.
      expect(find.byType(QuickActionButtonsBar, skipOffstage: false), findsOneWidget);
      expect(find.byType(QuickActionButtonsBar), findsNothing);
    });

    testWidgets('hides the minimize affordance when no SheetMinimizeScope is present', (WidgetTester tester) async {
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
