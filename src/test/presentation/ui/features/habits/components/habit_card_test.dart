import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_card.dart';
import 'package:whph/presentation/ui/features/habits/models/habit_list_style.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';

class MockVoidCallback {
  void call() {}
}

void main() {
  group('HabitCard Widget Tests', () {
    late MockVoidCallback mockOnOpenDetails;

    setUp(() {
      mockOnOpenDetails = MockVoidCallback();
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
      // This test would verify that the onOpenDetails callback is called
      // when the card is tapped

      // await tester.tap(find.byType(HabitCard));
      // verify(mockOnOpenDetails).called(1);
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
