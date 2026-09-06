import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/features/tasks/components/quick_add_task_dialog/quick_add_task_dialog.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

import 'quick_add_task_dialog_test_doubles.dart';

/// A host page that stands in for a real list page behind the dialog.
///
/// Both affordances are deliberately placed near the top of the screen, where
/// neither the bottom sheet nor the collapsed desktop bar can cover them, so a
/// blocked interaction can only be the modal barrier's doing.
class _BackgroundHostPage extends StatelessWidget {
  const _BackgroundHostPage({
    required this.scrollController,
    required this.onBackgroundButtonPressed,
  });

  final ScrollController scrollController;
  final VoidCallback onBackgroundButtonPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 60,
            child: Center(
              child: ElevatedButton(
                onPressed: onBackgroundButtonPressed,
                child: const Text('background-button'),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: 60,
              itemExtent: 50,
              itemBuilder: (context, index) => SizedBox(
                height: 50,
                child: Center(child: Text('background-item-$index')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(installFakeContainer);

  setUp(() => AppTheme.resetService());

  /// Runs [body] under [platform] and clears the override before the test body
  /// returns, because the framework asserts foundation debug vars are unset the
  /// moment the body completes - earlier than any `tearDown` would run.
  Future<void> withPlatform(TargetPlatform platform, Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  /// Drives the real [QuickAddTaskDialog.show] and returns probes for the
  /// background list offset and the background button tap count.
  Future<({ScrollController scrollController, int Function() tapCount})> showDialogOverBackground(
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    var backgroundTaps = 0;

    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return _BackgroundHostPage(
              scrollController: scrollController,
              onBackgroundButtonPressed: () => backgroundTaps++,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    QuickAddTaskDialog.show<String>(context: hostContext);
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddTaskDialog), findsOneWidget);

    return (scrollController: scrollController, tapCount: () => backgroundTaps);
  }

  /// Drags upward over the background list, well clear of the dialog surface.
  Future<void> dragBackgroundList(WidgetTester tester) async {
    await tester.dragFrom(const Offset(450, 200), const Offset(0, -200));
    await tester.pumpAndSettle();
  }

  Future<void> tapBackgroundButton(WidgetTester tester) async {
    await tester.tap(find.text('background-button'), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<void> tapTooltip(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  /// The whole point of minimizing is that the page behind becomes usable
  /// again, so assert on the page behind - not just on the dialog's own state.
  ///
  /// Scrolling carries the blocked/unblocked/blocked cycle because a drag is
  /// non-destructive; a tap on the barrier would dismiss the dialog and end the
  /// scenario, so tap blocking gets its own test below.
  void runBackgroundScrollTest(String platformLabel, TargetPlatform platform) {
    testWidgets('$platformLabel: background list scrolls only while minimized', (WidgetTester tester) async {
      await withPlatform(platform, () async {
        final probes = await showDialogOverBackground(tester);
        final scrollController = probes.scrollController;

        await dragBackgroundList(tester);
        expect(scrollController.offset, 0.0, reason: 'barrier must block scrolling while expanded');

        await tapTooltip(tester, TaskTranslationKeys.quickTaskMinimize);

        await dragBackgroundList(tester);
        expect(scrollController.offset, greaterThan(0.0), reason: 'background list must scroll while minimized');

        await tapBackgroundButton(tester);
        expect(probes.tapCount(), 1, reason: 'background button must be tappable while minimized');

        await tapTooltip(tester, TaskTranslationKeys.quickTaskRestore);

        final offsetAfterRestore = scrollController.offset;
        await dragBackgroundList(tester);
        expect(scrollController.offset, offsetAfterRestore, reason: 'barrier must block scrolling again after restore');
      });
    });
  }

  /// Tapping the background while expanded must reach the barrier, not the
  /// button - the barrier then dismisses the dialog, which is itself the proof
  /// that it owned the pointer.
  void runBackgroundTapBlockedTest(String platformLabel, TargetPlatform platform) {
    testWidgets('$platformLabel: background button is unreachable while expanded', (WidgetTester tester) async {
      await withPlatform(platform, () async {
        final probes = await showDialogOverBackground(tester);

        await tapBackgroundButton(tester);

        expect(probes.tapCount(), 0, reason: 'barrier must block taps while expanded');
        expect(find.byType(QuickAddTaskDialog), findsNothing, reason: 'the barrier consumed the tap and dismissed');
      });
    });
  }

  group('QuickAddTaskDialog background interaction while minimized', () {
    runBackgroundScrollTest('mobile', TargetPlatform.android);
    runBackgroundScrollTest('desktop', TargetPlatform.linux);
    runBackgroundTapBlockedTest('mobile', TargetPlatform.android);
    runBackgroundTapBlockedTest('desktop', TargetPlatform.linux);

    testWidgets('desktop dialog state survives minimize and restore', (WidgetTester tester) async {
      await withPlatform(TargetPlatform.linux, () async {
        await showDialogOverBackground(tester);

        await tester.enterText(find.byType(TextField).first, 'Desktop draft');
        await tester.pumpAndSettle();

        final stateBeforeMinimize = tester.state(find.byType(QuickAddTaskDialog));

        await tapTooltip(tester, TaskTranslationKeys.quickTaskMinimize);
        await tapTooltip(tester, TaskTranslationKeys.quickTaskRestore);

        expect(tester.state(find.byType(QuickAddTaskDialog)), same(stateBeforeMinimize));
        expect(find.text('Desktop draft'), findsOneWidget);
      });
    });
  });
}
