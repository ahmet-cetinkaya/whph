import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:application/features/habits/queries/get_list_habits_query.dart';
import 'package:application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_card/habit_card_metadata.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:domain/shared/constants/app_theme.dart' as domain;
import 'package:whph/main.dart' as app_main;
import 'package:acore/acore.dart' hide Container;

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

  Future<void> pumpWidget(WidgetTester tester, HabitListItem habit, {bool isDense = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HabitCardMetadata(
            habit: habit,
            isDense: isDense,
            translationService: mockTranslationService,
          ),
        ),
      ),
    );
  }

  group('HabitCardMetadata', () {
    testWidgets('renders tags', (tester) async {
      final habit = HabitListItem(
        id: '1',
        name: 'Work',
        tags: [TagListItem(id: 't1', name: 'Office', color: 'FF0000')],
      );

      await pumpWidget(tester, habit);

      // Use RichText checking because Label currently uses RichText for colored tags
      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);

      bool found = false;
      for (final widget in tester.widgetList<RichText>(richTextFinder)) {
        if (widget.text.toPlainText().contains('Office')) {
          found = true;
          break;
        }
      }
      expect(found, isTrue, reason: 'Should find RichText containing "Office"');
    });

    testWidgets('renders estimated time', (tester) async {
      final habit = HabitListItem(
        id: '1',
        name: 'Work',
        estimatedTime: 30, // 30 minutes
      );

      await pumpWidget(tester, habit);

      expect(find.text('30m'), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    });

    testWidgets('empty metadata renders nothing', (tester) async {
      final habit = HabitListItem(id: '1', name: 'Work');
      await pumpWidget(tester, habit);

      // Should be empty Wrap or similar, visual check implies height is 0 or no specific child text
      expect(find.byType(Wrap), findsOneWidget);
      expect(find.byType(Text), findsNothing); // No tags, no time
    });
  });
}
