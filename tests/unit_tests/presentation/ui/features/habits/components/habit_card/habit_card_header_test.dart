import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_card/habit_card_header.dart';
import 'package:whph/presentation/ui/features/habits/models/habit_list_style.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' as domain;
import 'package:whph/main.dart' as app_main;
import 'package:acore/acore.dart' hide Container;

// Create a mock for ITranslationService
class MockTranslationService extends Mock implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) {
    if (key == SharedTranslationKeys.untitled) return 'Untitled';
    return key;
  }
}

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

class FakeContainer extends Fake implements IContainer {
  IThemeService? themeService;

  @override
  T resolve<T>([String? name]) {
    if (T == IThemeService) {
      if (themeService == null) {
        throw Exception('ThemeService not initialized in FakeContainer');
      }
      return themeService as T;
    }
    throw UnimplementedError('FakeContainer.resolve($T)');
  }
}

void main() {
  late MockTranslationService mockTranslationService;
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
    mockTranslationService = MockTranslationService();
  });

  // Helper to pump the widget
  Future<void> pumpWidget(WidgetTester tester, HabitListItem habit,
      {bool isDense = false, HabitListStyle style = HabitListStyle.list}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HabitCardHeader(
            habit: habit,
            isDense: isDense,
            style: style,
            translationService: mockTranslationService,
          ),
        ),
      ),
    );
  }

  group('HabitCardHeader', () {
    testWidgets('renders habit name correctly', (tester) async {
      final habit = HabitListItem(id: '1', name: 'Exercise');
      await pumpWidget(tester, habit);

      expect(find.text('Exercise'), findsOneWidget);
    });

    testWidgets('renders Untitled when name is empty', (tester) async {
      final habit = HabitListItem(id: '1', name: '');
      await pumpWidget(tester, habit);

      expect(find.text('Untitled'), findsOneWidget);
    });

    testWidgets('shows metadata tags when present in list style', (tester) async {
      final habit = HabitListItem(
        id: '1',
        name: 'Reading',
        tags: [TagListItem(id: 't1', name: 'Learn', color: 'FF0000')],
      );

      await pumpWidget(tester, habit, style: HabitListStyle.list);

      // Verify Metadata key elements
      // Use RichText checking because Label currently uses RichText for colored tags
      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets); // Might be multiple (time + tags)

      bool found = false;
      for (final widget in tester.widgetList<RichText>(richTextFinder)) {
        if (widget.text.toPlainText().contains('Learn')) {
          found = true;
          break;
        }
      }
      expect(found, isTrue, reason: 'Should find RichText containing "Learn"');
    });

    testWidgets('hides metadata in grid style', (tester) async {
      final habit = HabitListItem(
        id: '1',
        name: 'Reading',
        tags: [TagListItem(id: 't1', name: 'Learn', color: 'FF0000')],
      );

      await pumpWidget(tester, habit, style: HabitListStyle.grid);

      expect(find.text('Learn'), findsNothing);
    });
  });
}
