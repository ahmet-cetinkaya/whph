/// Screenshot integration test for automated screenshot capture.
///
/// This test runs through the app and captures screenshots.
/// Run with: flutter drive --driver=test_driver/integration_test.dart \
///           --target=integration_test/screenshot_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whph/main.dart' as app;

import 'screenshot_config.dart';

void main() {
  final IntegrationTestWidgetsFlutterBinding binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Store original ErrorWidget.builder to restore after test
  final originalErrorBuilder = ErrorWidget.builder;

  group('Screenshot Capture', () {
    testWidgets('Capture all screenshot scenarios', (WidgetTester tester) async {
      debugPrint('🚀 Starting screenshot capture...');

      // Launch the main WHPH app
      app.main([]);

      // Wait for app to initialize
      await _waitForAppInit(tester);
      debugPrint('✅ App initialized');

      // Dismiss the onboarding dialog if present
      await _dismissOnboardingDialog(tester);
      debugPrint('✅ Onboarding dismissed, starting screenshot capture...');

      // Convert surface once
      await binding.convertFlutterSurfaceToImage();

      // Capture screenshots for each scenario
      for (final scenario in ScreenshotConfig.scenarios) {
        debugPrint('📸 Processing scenario ${scenario.id}: ${scenario.name}');

        await _captureScenario(
          tester: tester,
          binding: binding,
          scenario: scenario,
        );
      }

      debugPrint('🎉 Screenshot capture completed!');
      debugPrint('📁 Pull screenshots with: adb pull /data/local/tmp/whph_screenshots/');

      // Restore ErrorWidget.builder
      ErrorWidget.builder = originalErrorBuilder;
    });
  });
}

/// Wait for app initialization.
Future<void> _waitForAppInit(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Dismiss the onboarding dialog by tapping through it.
Future<void> _dismissOnboardingDialog(WidgetTester tester) async {
  debugPrint('🔍 Looking for onboarding dialog...');
  await tester.pump(const Duration(seconds: 1));

  for (int page = 0; page < 5; page++) {
    final nextButtonFinder = find.byType(FilledButton);

    if (nextButtonFinder.evaluate().isEmpty) {
      break;
    }

    final skipFinder = find.textContaining('Skip');
    if (skipFinder.evaluate().isNotEmpty) {
      final skipButton = find.byType(OutlinedButton);
      if (skipButton.evaluate().isNotEmpty) {
        await tester.tap(skipButton.first);
        await _waitForScreen(tester, 1);
        break;
      }
    }

    await tester.tap(nextButtonFinder.first);
    await _waitForScreen(tester, 1);
  }

  await _waitForScreen(tester, 1);
}

/// Captures a single screenshot scenario.
Future<void> _captureScenario({
  required WidgetTester tester,
  required IntegrationTestWidgetsFlutterBinding binding,
  required ScreenshotScenario scenario,
}) async {
  try {
    // Step 1: Navigate to route if specified
    if (scenario.route.isNotEmpty) {
      await _navigateToScreen(tester, scenario.route);
    }

    // Step 2: Tap on specific text if specified
    if (scenario.tapText != null) {
      debugPrint('  👆 Tapping on: "${scenario.tapText}"');
      await _tapOnText(tester, scenario.tapText!);
    }

    // Step 3: Tap first item if specified
    if (scenario.tapFirst) {
      debugPrint('  👆 Tapping first item in list');
      await _tapFirstListItem(tester);
    }

    // Step 4: Scroll to text if specified
    if (scenario.scrollToText != null) {
      debugPrint('  📜 Scrolling to: "${scenario.scrollToText}"');
      await _scrollToText(tester, scenario.scrollToText!);
    }

    // Step 5: Simple scroll down if specified
    if (scenario.scrollDown) {
      debugPrint('  📜 Scrolling down...');
      await _scrollDown(tester);
    }

    // Step 6: Wait for UI to stabilize
    debugPrint('  ⏳ Waiting ${scenario.waitSeconds}s...');
    await _waitForScreen(tester, scenario.waitSeconds);

    // Step 7: Take screenshot
    final String screenshotName = '${scenario.id}';
    debugPrint('  📷 Taking screenshot "$screenshotName" (${scenario.name})...');

    try {
      await binding.takeScreenshot(screenshotName);
      debugPrint('✅ Screenshot ${scenario.id} captured: ${scenario.name}');
    } catch (e) {
      debugPrint('  ⚠️ Screenshot error: $e');
    }
  } catch (e) {
    debugPrint('❌ Failed to capture ${scenario.name}: $e');
  }
}

/// Tap on text to navigate to a details page.
Future<void> _tapOnText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  if (finder.evaluate().isNotEmpty) {
    await tester.tap(finder.first);
    await _waitForScreen(tester, 2);
    debugPrint('  ✅ Tapped on "$text"');
  } else {
    // Try partial match
    final partialFinder = find.textContaining(text);
    if (partialFinder.evaluate().isNotEmpty) {
      await tester.tap(partialFinder.first);
      await _waitForScreen(tester, 2);
      debugPrint('  ✅ Tapped on text containing "$text"');
    } else {
      debugPrint('  ⚠️ Text "$text" not found');
    }
  }
}

/// Tap the first item in a list (typically ListTile or Card).
Future<void> _tapFirstListItem(WidgetTester tester) async {
  // Try ListTile first
  final listTileFinder = find.byType(ListTile);
  if (listTileFinder.evaluate().isNotEmpty) {
    await tester.tap(listTileFinder.first);
    await _waitForScreen(tester, 2);
    debugPrint('  ✅ Tapped first ListTile');
    return;
  }

  // Try Card
  final cardFinder = find.byType(Card);
  if (cardFinder.evaluate().isNotEmpty) {
    await tester.tap(cardFinder.first, warnIfMissed: false);
    await _waitForScreen(tester, 2);
    debugPrint('  ✅ Tapped first Card');
    return;
  }

  // Try InkWell
  final inkWellFinder = find.byType(InkWell);
  if (inkWellFinder.evaluate().isNotEmpty) {
    await tester.tap(inkWellFinder.first);
    await _waitForScreen(tester, 2);
    debugPrint('  ✅ Tapped first InkWell');
    return;
  }

  debugPrint('  ⚠️ No tappable list item found');
}

/// Scroll to make text visible using simple drag gestures.
Future<void> _scrollToText(WidgetTester tester, String text) async {
  // Find a vertical scrollable (SingleChildScrollView, ListView, etc.)
  final scrollFinder = find.byWidgetPredicate(
    (widget) => widget is Scrollable && (widget).axisDirection == AxisDirection.down,
  );

  if (scrollFinder.evaluate().isEmpty) {
    debugPrint('  ⚠️ No vertical scrollable found, trying manual scroll...');
    // Try manual scroll by dragging screen - use .first in case multiple Scaffolds
    final scaffoldFinder = find.byType(Scaffold);
    if (scaffoldFinder.evaluate().isNotEmpty) {
      await tester.drag(scaffoldFinder.first, const Offset(0, -300));
    }
    await _waitForScreen(tester, 1);
    return;
  }

  final targetFinder = find.textContaining(text);

  try {
    await tester.scrollUntilVisible(
      targetFinder,
      200.0,
      scrollable: scrollFinder.first,
    );
    await _waitForScreen(tester, 1);
    debugPrint('  ✅ Scrolled to "$text"');
  } catch (e) {
    debugPrint('  ⚠️ Could not scroll to "$text", trying manual scroll...');
    // Manual scroll fallback - use .first in case multiple Scaffolds
    final scaffoldFinder = find.byType(Scaffold);
    if (scaffoldFinder.evaluate().isNotEmpty) {
      await tester.drag(scaffoldFinder.first, const Offset(0, -300));
    }
    await _waitForScreen(tester, 1);
  }
}

/// Simple scroll down by a fixed amount.
Future<void> _scrollDown(WidgetTester tester) async {
  // Find a vertical scrollable first
  final scrollFinder = find.byWidgetPredicate(
    (widget) => widget is Scrollable && (widget).axisDirection == AxisDirection.down,
  );

  if (scrollFinder.evaluate().isNotEmpty) {
    await tester.drag(scrollFinder.first, const Offset(0, -400));
    await _waitForScreen(tester, 1);
    debugPrint('  ✅ Scrolled down');
  } else {
    // Fallback to Scaffold
    final scaffoldFinder = find.byType(Scaffold);
    if (scaffoldFinder.evaluate().isNotEmpty) {
      await tester.drag(scaffoldFinder.first, const Offset(0, -400));
      await _waitForScreen(tester, 1);
      debugPrint('  ✅ Scrolled down (via Scaffold)');
    }
  }
}

/// Wait for screen to render using fixed pumps.
Future<void> _waitForScreen(WidgetTester tester, int seconds) async {
  final int iterations = seconds * 2;
  for (int i = 0; i < iterations; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Navigates to the specified screen route.
Future<void> _navigateToScreen(WidgetTester tester, String route) async {
  debugPrint('  🧭 Navigating to: $route');

  final navigatorState = app.navigatorKey.currentState;

  if (navigatorState != null) {
    // Main screens clear the stack to remove back button
    const mainRoutes = ['/today', '/tasks', '/habits', '/notes', '/tags', '/app-usages'];
    if (mainRoutes.contains(route)) {
      // Clear entire stack and push new route (no back button)
      navigatorState.pushNamedAndRemoveUntil(route, (route) => false);
    } else {
      navigatorState.pushNamed(route);
    }
    await _waitForScreen(tester, 2);
    debugPrint('  ✅ Navigated to: $route');
  } else {
    debugPrint('  ❌ Navigator not available');
  }
}
