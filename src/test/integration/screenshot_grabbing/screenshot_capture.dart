/// Screenshot integration test for automated screenshot capture.
///
/// This test runs through the app and captures screenshots.
/// Run with: flutter drive --driver=test_driver/integration_test.dart \
///           --target=test/integration/screenshot_grabbing/screenshot_test.dart \
///           --dart-define=SCREENSHOT_LOCALE=en
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whph/main.dart' as app;
import 'package:whph/core/application/features/demo/translations/demo_translations_registry.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_statistics_view.dart';
import 'package:whph/presentation/ui/features/app_usages/components/app_usage_statistics_view.dart';

import 'screenshot_config.dart';

/// Get the screenshot locale from dart-define (default: en)
const String _screenshotLocale = String.fromEnvironment('SCREENSHOT_LOCALE', defaultValue: 'en');

void main() {
  final IntegrationTestWidgetsFlutterBinding binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Store original ErrorWidget.builder to restore after test
  final originalErrorBuilder = ErrorWidget.builder;

  group('Screenshot Capture', () {
    testWidgets('Capture all screenshot scenarios', (WidgetTester tester) async {
      debugPrint('🚀 Starting screenshot capture for locale: $_screenshotLocale');

      // Launch the main WHPH app
      app.main([]);

      // Wait for app to initialize
      await _waitForAppInit(tester);
      debugPrint('✅ App initialized');

      // Change app locale to target language
      await _changeAppLocale(tester, _screenshotLocale);
      debugPrint('✅ App locale changed to: $_screenshotLocale');

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

      debugPrint('🎉 Screenshot capture completed for locale: $_screenshotLocale');

      // Restore ErrorWidget.builder
      ErrorWidget.builder = originalErrorBuilder;
    });
  });
}

/// Wait for app initialization.
Future<void> _waitForAppInit(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(seconds: 10),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 2),
  );
}

/// Change the app's locale to the target language.
Future<void> _changeAppLocale(WidgetTester tester, String localeCode) async {
  debugPrint('  🌐 Changing locale to: $localeCode');

  // Find the context and change locale
  final BuildContext? context = _findAppContext(tester);
  if (context != null) {
    await context.setLocale(Locale(localeCode));
    await tester.pumpAndSettle();
    await _waitForScreen(tester, 2);
    debugPrint('  ✅ Locale changed successfully');
  } else {
    debugPrint('  ⚠️ Could not find context to change locale');
  }
}

/// Find the app's BuildContext.
BuildContext? _findAppContext(WidgetTester tester) {
  try {
    final finder = find.byType(MaterialApp);
    if (finder.evaluate().isNotEmpty) {
      return finder.evaluate().first.toStringDeep().isNotEmpty ? tester.element(finder.first) : null;
    }
  } catch (e) {
    debugPrint('  ⚠️ Error finding context: $e');
  }
  return null;
}

/// Dismiss the onboarding dialog by navigating through pages and skipping the tour.
Future<void> _dismissOnboardingDialog(WidgetTester tester) async {
  debugPrint('🔍 Looking for onboarding dialog...');
  await tester.pump(const Duration(seconds: 1));

  // Navigate through all onboarding pages (up to 10 pages max as safety limit)
  for (int page = 0; page < 10; page++) {
    // Check if dialog is still present by looking for FilledButton
    final filledButtonFinder = find.byType(FilledButton);
    if (filledButtonFinder.evaluate().isEmpty) {
      debugPrint('  ✅ Onboarding dialog closed');
      break;
    }

    // Check if we're on the last page (which has both OutlinedButton and FilledButton)
    final outlinedButtonFinder = find.byType(OutlinedButton);
    if (outlinedButtonFinder.evaluate().isNotEmpty) {
      // On the last page, tap the OutlinedButton (Skip Tour)
      debugPrint('  👆 Tapping Skip Tour button...');
      await tester.tap(outlinedButtonFinder.first);
      await _waitForScreen(tester, 1);
      debugPrint('  ✅ Skipped tour');
      break;
    }

    // Not on the last page, tap Next (FilledButton)
    debugPrint('  👆 Tapping Next button (page ${page + 1})...');
    await tester.tap(filledButtonFinder.first);
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

    // Step 3b: Tap on translated text if translation key specified
    if (scenario.tapTranslationKey != null) {
      final translatedText = DemoTranslationsRegistry.translate(scenario.tapTranslationKey!, _screenshotLocale);
      debugPrint('  👆 Tapping on translated text: "$translatedText" (key: ${scenario.tapTranslationKey})');
      await _tapOnText(tester, translatedText);
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

    // Step 6: Scroll up (to top) if specified
    if (scenario.scrollUp) {
      debugPrint('  📜 Scrolling up to top...');
      await _scrollUp(tester);
    }

    // Step 6b: Custom scroll offset if specified
    if (scenario.scrollOffset != null) {
      debugPrint('  📜 Scrolling by offset: ${scenario.scrollOffset}px');
      await _scrollByOffset(tester, scenario.scrollOffset!);
    }

    // Step 6c: Scroll to specific widget type if specified
    if (scenario.scrollToWidgetType != null) {
      debugPrint('  📜 Scrolling to widget: ${scenario.scrollToWidgetType}');
      await _scrollToWidgetType(tester, scenario.scrollToWidgetType!);
    }

    // Step 7: Wait for UI to stabilize
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

/// Scroll up to the top of the page.
Future<void> _scrollUp(WidgetTester tester) async {
  // Use Scaffold-based scrolling first as it's more reliable for nested scrollables
  final scaffoldFinder = find.byType(Scaffold);
  if (scaffoldFinder.evaluate().isNotEmpty) {
    try {
      await tester.drag(scaffoldFinder.first, const Offset(0, 800), warnIfMissed: false);
      await _waitForScreen(tester, 1);
      debugPrint('  ✅ Scrolled up to top');
      return;
    } catch (e) {
      debugPrint('  ⚠️ Scaffold scroll failed: $e');
    }
  }

  // Fallback: try SingleChildScrollView
  final scrollViewFinder = find.byType(SingleChildScrollView);
  if (scrollViewFinder.evaluate().isNotEmpty) {
    try {
      await tester.drag(scrollViewFinder.first, const Offset(0, 800), warnIfMissed: false);
      await _waitForScreen(tester, 1);
      debugPrint('  ✅ Scrolled up to top (via SingleChildScrollView)');
      return;
    } catch (e) {
      debugPrint('  ⚠️ SingleChildScrollView scroll failed: $e');
    }
  }

  // Final fallback: try any scrollable with warnIfMissed
  final scrollFinder = find.byWidgetPredicate(
    (widget) => widget is Scrollable && (widget).axisDirection == AxisDirection.down,
  );
  if (scrollFinder.evaluate().isNotEmpty) {
    try {
      await tester.drag(scrollFinder.first, const Offset(0, 800), warnIfMissed: false);
      await _waitForScreen(tester, 1);
      debugPrint('  ✅ Scrolled up to top (via Scrollable)');
    } catch (e) {
      debugPrint('  ⚠️ Scrollable scroll failed: $e');
    }
  }
}

/// Scroll by a custom offset (positive = up, negative = down).
Future<void> _scrollByOffset(WidgetTester tester, double offset) async {
  // Use Scaffold-based scrolling as it's most reliable
  final scaffoldFinder = find.byType(Scaffold);
  if (scaffoldFinder.evaluate().isNotEmpty) {
    try {
      await tester.drag(scaffoldFinder.first, Offset(0, offset), warnIfMissed: false);
      await _waitForScreen(tester, 1);
      debugPrint('  ✅ Scrolled by offset: ${offset}px');
      return;
    } catch (e) {
      debugPrint('  ⚠️ Scaffold scroll failed: $e');
    }
  }

  // Fallback: try SingleChildScrollView
  final scrollViewFinder = find.byType(SingleChildScrollView);
  if (scrollViewFinder.evaluate().isNotEmpty) {
    try {
      await tester.drag(scrollViewFinder.first, Offset(0, offset), warnIfMissed: false);
      await _waitForScreen(tester, 1);
      debugPrint('  ✅ Scrolled by offset via SingleChildScrollView');
      return;
    } catch (e) {
      debugPrint('  ⚠️ SingleChildScrollView scroll failed: $e');
    }
  }
}

/// Scroll to a specific widget type by name.
Future<void> _scrollToWidgetType(WidgetTester tester, String widgetTypeName) async {
  // Map widget type names to their actual types
  final Type? widgetType = _getWidgetType(widgetTypeName);

  if (widgetType == null) {
    debugPrint('  ⚠️ Unknown widget type: $widgetTypeName');
    return;
  }

  final finder = find.byType(widgetType);
  if (finder.evaluate().isEmpty) {
    debugPrint('  ⚠️ Widget not found: $widgetTypeName');
    return;
  }

  try {
    // Scroll widget into view
    await tester.ensureVisible(finder.first);
    await _waitForScreen(tester, 1);
    debugPrint('  ✅ Scrolled to $widgetTypeName');
  } catch (e) {
    debugPrint('  ⚠️ Could not scroll to $widgetTypeName: $e');
  }
}

/// Get widget Type from string name.
Type? _getWidgetType(String typeName) {
  switch (typeName) {
    case 'HabitStatisticsView':
      return HabitStatisticsView;
    case 'AppUsageStatisticsView':
      return AppUsageStatisticsView;
    default:
      return null;
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
