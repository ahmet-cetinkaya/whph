import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/domain/features/tasks/models/recurrence_configuration.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_recurrence_selector/recurrence_weekly_time_selector.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:acore/time/week_days.dart';

class FakeITranslationService implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) {
    return key.split('.').last; 
  }

  // Implement other members if necessary, or just throw UnimplementedError
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeITranslationService fakeTranslationService;

  setUp(() {
    fakeTranslationService = FakeITranslationService();
  });

  Widget createWidget({
    List<WeekDays> selectedDays = const [],
    List<WeeklySchedule>? schedule,
    required ValueChanged<List<WeeklySchedule>> onScheduleChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: RecurrenceWeeklyTimeSelector(
          selectedDays: selectedDays,
          schedule: schedule,
          onScheduleChanged: onScheduleChanged,
          translationService: fakeTranslationService,
        ),
      ),
    );
  }

  testWidgets('renders nothing when no days selected', (tester) async {
    await tester.pumpWidget(createWidget(
      onScheduleChanged: (_) {},
    ));

    expect(find.byType(Column), findsNothing);
  });

  testWidgets('renders rows for selected days', (tester) async {
    final days = [WeekDays.monday, WeekDays.friday];
    
    await tester.pumpWidget(createWidget(
      selectedDays: days,
      onScheduleChanged: (_) {},
    ));

    // Based on key.split('.').last implementation in Fake
    expect(find.text('monday'), findsOneWidget);
    expect(find.text('friday'), findsOneWidget);
    // Default time check
    expect(find.text('9:00 AM'), findsNWidgets(2)); 
  });

  testWidgets('renders specific times from schedule', (tester) async {
    final days = [WeekDays.monday];
    final schedule = [
      const WeeklySchedule(dayOfWeek: 1, hour: 14, minute: 30),
    ];

    await tester.pumpWidget(createWidget(
      selectedDays: days,
      schedule: schedule,
      onScheduleChanged: (_) {},
    ));

    expect(find.text('2:30 PM'), findsOneWidget);
  });
}
