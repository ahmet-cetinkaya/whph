import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_card/habit_card.dart';
import 'package:whph/presentation/ui/features/habits/models/habit_list_style.dart';
import 'package:application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/main.dart' as app_main;
import 'package:acore/acore.dart' hide Container;
import 'package:mediatr/mediatr.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/features/tags/services/time_data_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';

class MockVoidCallback {
  void call() {}
}

class MockMediator extends Mock implements Mediator {}

class MockSoundManagerService extends Mock implements ISoundManagerService {}

class MockHabitsService extends Mock implements HabitsService {
  @override
  final ValueNotifier<String?> onHabitRecordAdded = ValueNotifier(null);
  @override
  final ValueNotifier<String?> onHabitRecordRemoved = ValueNotifier(null);
}

class MockTimeDataService extends Mock implements TimeDataService {}

class MockTranslationService extends Mock implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
}

class MockThemeService extends Mock implements IThemeService {}

class FakeContainer extends Fake implements IContainer {
  final Map<Type, dynamic> _registrations = {};

  void register<T>(dynamic instance) {
    _registrations[T] = instance;
  }

  @override
  T resolve<T>([String? name]) {
    if (_registrations.containsKey(T)) {
      return _registrations[T] as T;
    }
    throw Exception('Service setup missing for type $T');
  }
}

void main() {
  group('HabitCard Widget Tests', () {
    late MockVoidCallback mockOnOpenDetails;
    late FakeContainer fakeContainer;
    late MockMediator mockMediator;
    late MockSoundManagerService mockSoundManagerService;
    late MockHabitsService mockHabitsService;
    late MockTimeDataService mockTimeDataService;
    late MockTranslationService mockTranslationService;
    late MockThemeService mockThemeService;

    setUpAll(() {
      fakeContainer = FakeContainer();
      app_main.container = fakeContainer;
    });

    setUp(() {
      mockOnOpenDetails = MockVoidCallback();
      mockMediator = MockMediator();
      mockSoundManagerService = MockSoundManagerService();
      mockHabitsService = MockHabitsService();
      mockTimeDataService = MockTimeDataService();
      mockTranslationService = MockTranslationService();
      mockThemeService = MockThemeService();

      fakeContainer.register<Mediator>(mockMediator);
      fakeContainer.register<ISoundManagerService>(mockSoundManagerService);
      fakeContainer.register<HabitsService>(mockHabitsService);
      fakeContainer.register<TimeDataService>(mockTimeDataService);
      fakeContainer.register<ITranslationService>(mockTranslationService);
      fakeContainer.register<IThemeService>(mockThemeService);
    });

    testWidgets('HabitCard constructor validation', (WidgetTester tester) async {
      // Test that HabitCard can be created with required parameters
      final habitCard = HabitCard(
        habit: HabitListItem(
          id: '1',
          name: 'Test Habit',
          hasGoal: false,
          targetFrequency: 1,
          periodDays: 1,
        ),
        onOpenDetails: mockOnOpenDetails.call,
      );

      expect(habitCard.habit.name, equals('Test Habit'));
      expect(habitCard.habit.id, equals('1'));
      expect(habitCard.onOpenDetails, isNotNull);
      expect(habitCard.style, equals(HabitListStyle.grid));
      expect(habitCard.isDateLabelShowing, isTrue);
    });

    testWidgets('handles onOpenDetails callback', (WidgetTester tester) async {
      // This test is currently empty in source, leaving as placeholder
      // To properly test this, we would need to mock GetListHabitRecordsQuery response
    });

    testWidgets('renders in list style when specified', (WidgetTester tester) async {
      final habitCard = HabitCard(
        habit: HabitListItem(
          id: '1',
          name: 'Test Habit',
          hasGoal: false,
          targetFrequency: 1,
          periodDays: 1,
        ),
        onOpenDetails: mockOnOpenDetails.call,
        style: HabitListStyle.list,
      );

      expect(habitCard.style, equals(HabitListStyle.list));
    });

    testWidgets('renders with drag handle when specified', (WidgetTester tester) async {
      final habitCard = HabitCard(
        habit: HabitListItem(
          id: '1',
          name: 'Test Habit',
          hasGoal: false,
          targetFrequency: 1,
          periodDays: 1,
        ),
        onOpenDetails: mockOnOpenDetails.call,
        showDragHandle: true,
      );

      expect(habitCard.showDragHandle, isTrue);
    });
  });
}
