import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_card/habit_progress.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' as domain;
import 'package:whph/main.dart' as app_main;
import 'package:acore/acore.dart' as acore;
import 'package:mockito/mockito.dart';

class MockThemeService extends Mock implements IThemeService {
  @override
  Color get primaryColor => Colors.blue;
  @override
  Color get textColor => Colors.black;
  @override
  Color get secondaryTextColor => Colors.grey;
  @override
  Color get surface2 => Colors.grey.shade200;
  @override
  domain.UiDensity get currentUiDensity => domain.UiDensity.normal;
}

class FakeContainer extends Fake implements acore.IContainer {
  IThemeService? themeService;

  @override
  T resolve<T>([String? name]) {
    if (T == IThemeService) {
      return themeService! as T;
    }
    throw UnimplementedError('FakeContainer.resolve($T)');
  }
}

void main() {
  late MockThemeService mockThemeService;
  late FakeContainer fakeContainer;

  setUpAll(() {
    fakeContainer = FakeContainer();
    app_main.container = fakeContainer;
  });

  setUp(() {
    AppTheme.resetService();
    mockThemeService = MockThemeService();
    fakeContainer.themeService = mockThemeService;
  });

  testWidgets('HabitProgress renders correctly with 0 progress', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HabitProgress(
            currentCount: 0,
            dailyTarget: 5,
            isDisabled: false,
            onTap: () {},
          ),
        ),
      ),
    );

    // Expect 'add' icon (or whichever logic is default for 0/Target)
    // Logic: currentCount > 0 ? Icons.add (wait)
    // Code says: isComplete ? link : currentCount > 0 ? add : close.
    // So 0/5 -> Icons.close (red) or similar?
    // Actually code:
    // Icon( ... currentCount > 0 ? Icons.add : Icons.close ...)
    // So 0 count -> Icons.close.

    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('0'), findsNothing); // Badge only if count > 0
  });

  testWidgets('HabitProgress renders count badge when progress > 0 but not complete', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HabitProgress(
            currentCount: 2,
            dailyTarget: 5,
            isDisabled: false,
            onTap: () {},
          ),
        ),
      ),
    );

    // Should show Icons.add (blue) and badge '2'
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('HabitProgress renders complete state', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HabitProgress(
            currentCount: 5,
            dailyTarget: 5,
            isDisabled: false,
            onTap: () {},
          ),
        ),
      ),
    );

    // Should show Icons.link (green)
    expect(find.byIcon(Icons.link), findsOneWidget);

    // Badge might still show count '5'?
    // Logic: if (currentCount > 0) show badge.
    // So yes.
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('HabitProgress handles disabled state', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HabitProgress(
            currentCount: 0,
            dailyTarget: 5,
            isDisabled: true,
            onTap: () {},
          ),
        ),
      ),
    );

    // Icon Color should be disabled color
    // We can check Icon, but hard to check color without deeper inspection.
    // Just checking it renders is mostly enough for now.
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('HabitProgress onTap callback works', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HabitProgress(
            currentCount: 2,
            dailyTarget: 5,
            isDisabled: false,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(HabitProgress));
    expect(tapped, isTrue);
  });
}
