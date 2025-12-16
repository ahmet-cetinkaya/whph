import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/main.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/components/load_more_button.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';

// Mocks
class FakeContainer extends Fake implements IContainer {
  final Map<Type, Object> _instances = {};

  void register<T>(T instance) {
    _instances[T] = instance as Object;
  }

  @override
  T resolve<T>() {
    if (!_instances.containsKey(T)) {
      throw Exception('Type $T not registered in FakeContainer');
    }
    return _instances[T] as T;
  }
}

class MockITranslationService extends Mock implements ITranslationService {
  @override
  String translate(String? key, {Map<String, dynamic>? namedArgs}) {
    if (key == SharedTranslationKeys.loadMoreButton) return 'Load More';
    return key ?? '';
  }
}

void main() {
  late FakeContainer fakeContainer;
  late MockITranslationService mockTranslationService;

  setUpAll(() {
    fakeContainer = FakeContainer();
    try {
      container = fakeContainer; // Override global container
    } catch (_) {
      // Ignored if already initialized
    }
  });

  setUp(() {
    mockTranslationService = MockITranslationService();
    fakeContainer.register<ITranslationService>(mockTranslationService);
  });

  Widget createWidgetUnderTest({
    required Future<void> Function() onPressed,
    Size screenSize = const Size(800, 600), // Default large screen
  }) {
    return MediaQuery(
      data: MediaQueryData(size: screenSize),
      child: MaterialApp(
        home: Scaffold(
          body: LoadMoreButton(
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }

  group('LoadMoreButton -', () {
    testWidgets('renders correctly on large screen', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        onPressed: () async {},
        screenSize: const Size(800, 600),
      ));

      final textFinder = find.text('Load More');
      expect(textFinder, findsOneWidget);

      // Verify full width by checking constraints
      // The button style minimumSize applies constraints via ConstrainedBox
      final constrainedBoxFinder = find.ancestor(
        of: textFinder,
        matching: find.byType(ConstrainedBox),
      );

      bool foundFullWidth = false;
      for (final element in constrainedBoxFinder.evaluate()) {
        final widget = (element as Element).widget as ConstrainedBox;
        if (widget.constraints.minWidth == double.infinity) {
          foundFullWidth = true;
          break;
        }
      }

      expect(foundFullWidth, isTrue, reason: 'Button should be full width (minWidth: infinity)');

      // Verify height
      final buttonFinder = find.descendant(
        of: find.byType(LoadMoreButton),
        matching: find.byWidgetPredicate((widget) => widget is TextButton),
      );

      expect(buttonFinder, findsOneWidget, reason: 'Should find exactly one TextButton inside LoadMoreButton');

      final buttonStyle = tester.widget<TextButton>(buttonFinder).style!;
      final minSize = buttonStyle.minimumSize?.resolve({});
      expect(minSize?.height, AppTheme.buttonSizeXLarge,
          reason: 'Button height should be XLarge (48.0) on large screen');
    });

    testWidgets('renders correctly on small screen', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        onPressed: () async {},
        screenSize: const Size(300, 600), // Small width
      ));

      expect(find.text('Load More'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('triggers onPressed when tapped', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(createWidgetUnderTest(
        onPressed: () async {
          pressed = true;
        },
      ));

      await tester.tap(find.byType(LoadMoreButton));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('shows loading state when pressed', (tester) async {
      final completer = Completer<void>();
      await tester.pumpWidget(createWidgetUnderTest(
        onPressed: () => completer.future,
      ));

      final buttonFinder = find.ancestor(
        of: find.text('Load More'),
        matching: find.byWidgetPredicate((widget) => widget is TextButton),
      );
      expect(buttonFinder, findsOneWidget, reason: 'Button should exist initially');

      await tester.tap(find.byType(LoadMoreButton));
      await tester.pump(); // Start loading

      expect(buttonFinder, findsOneWidget, reason: 'Button should exist during loading');

      final button = tester.widget<TextButton>(buttonFinder.first);
      expect(button.onPressed, isNull, reason: 'Button should be disabled when loading');

      // Verify loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget,
          reason: 'CircularProgressIndicator should be visible');
      expect(find.byType(Icon), findsNothing, reason: 'Icon should not be visible when loading');

      completer.complete();
      await tester.pump(); // Finish loading

      final buttonEnabled = tester.widget<TextButton>(buttonFinder.first);
      expect(buttonEnabled.onPressed, isNotNull, reason: 'Button should be enabled after loading');
    });

    testWidgets('uses correct styling on mobile screen', (tester) async {
      // This test asserts the DESIRED mobile friendly changes.
      // It is expected to FAIL until we apply the fixes.

      await tester.pumpWidget(createWidgetUnderTest(
        onPressed: () async {},
        screenSize: const Size(300, 600),
      ));

      // 1. Check Font Size
      final textFinder = find.text('Load More');
      final textWidget = tester.widget<Text>(textFinder);
      // Desired: AppTheme.fontSizeMedium (14.0) instead of current 11.0
      expect(textWidget.style?.fontSize, AppTheme.fontSizeMedium, reason: 'Font size should be medium on mobile');

      // 2. Check Icon Size
      final iconFinder = find.byType(Icon);
      final iconWidget = tester.widget<Icon>(iconFinder);
      // Desired: AppTheme.iconSizeMedium (20.0) instead of current 12.0
      expect(iconWidget.size, AppTheme.iconSizeMedium, reason: 'Icon size should be medium on mobile');

      // 3. Check Minimum Size (Height and Width)
      final buttonFinder = find.byType(TextButton);
      final buttonStyle = tester.widget<TextButton>(find.byType(TextButton)).style!;
      final minSize = buttonStyle.minimumSize?.resolve({});
      // Desired: AppTheme.buttonSizeLarge (44.0) height
      expect(minSize?.height, AppTheme.buttonSizeXLarge, reason: 'Button height should be large on mobile');

      // Desired: double.infinity width
      expect(minSize?.width, double.infinity, reason: 'Button width should be infinity (full width) on mobile');
    });
  });
}
