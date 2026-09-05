import 'package:acore/acore.dart' hide Container;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:mockito/mockito.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' as domain;
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/habits/components/habit_statistics_view.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class FakeMediator extends Fake implements Mediator {
  GetHabitQueryResponse? habitResponse;

  @override
  Future<R> send<T extends IRequest<R>, R extends Object?>(T request) async {
    if (request is GetHabitQuery) return habitResponse! as R;
    if (request is GetListHabitRecordsQuery) {
      return GetListHabitRecordsQueryResponse(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 1000) as R;
    }
    throw UnimplementedError('FakeMediator.send(${request.runtimeType})');
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
  Color get surface1 => Colors.white;
  @override
  domain.UiDensity get currentUiDensity => domain.UiDensity.normal;
}

class MockTranslationService extends Mock implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
}

class FakeContainer extends Fake implements IContainer {
  final Map<Type, dynamic> _registrations = {};

  void register<T>(dynamic instance) => _registrations[T] = instance;

  @override
  T resolve<T>([String? name]) {
    if (_registrations.containsKey(T)) return _registrations[T] as T;
    throw Exception('Service setup missing for type $T');
  }
}

void main() {
  const habitId = 'habit-1';

  late FakeContainer fakeContainer;
  late FakeMediator fakeMediator;
  late MockThemeService mockThemeService;
  late MockTranslationService mockTranslationService;

  setUpAll(() {
    tz.initializeTimeZones();
    fakeContainer = FakeContainer();
    app_main.container = fakeContainer;
  });

  setUp(() {
    AppTheme.resetService();
    fakeMediator = FakeMediator();
    mockThemeService = MockThemeService();
    mockTranslationService = MockTranslationService();

    fakeContainer.register<Mediator>(fakeMediator);
    fakeContainer.register<HabitsService>(HabitsService());
    fakeContainer.register<IThemeService>(mockThemeService);
    fakeContainer.register<ITranslationService>(mockTranslationService);
  });

  List<MapEntry<DateTime, double>> trailingTwelveMonths(double Function(int index) score) {
    final anchor = DateTime(2026, 4, 15);
    return List.generate(
      12,
      (index) => MapEntry(DateTime(anchor.year, anchor.month - (11 - index), 1), score(index)),
    );
  }

  GetHabitQueryResponse habitResponse({
    required HabitType type,
    required List<MapEntry<DateTime, double>> monthlyScores,
  }) {
    return GetHabitQueryResponse(
      id: habitId,
      createdDate: DateTime(2025, 5, 1),
      type: type,
      name: 'Habit',
      description: '',
      statistics: HabitStatistics(
        overallScore: 0.5,
        monthlyScore: 0.5,
        yearlyScore: 0.5,
        totalRecords: 3,
        monthlyScores: monthlyScores,
        topStreaks: const [],
        yearlyFrequency: const {},
      ),
    );
  }

  Future<void> pumpStatisticsView(WidgetTester tester, GetHabitQueryResponse habit) async {
    fakeMediator.habitResponse = habit;

    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1100,
              child: HabitStatisticsView(habitId: habitId),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> renderedMonthLabels(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .where((data) => data.startsWith('shared.calendar.months.'))
        .toList();
  }

  for (final type in HabitType.values) {
    testWidgets('Given ${type.name} habit statistics When the score chart renders Then each month is labelled once',
        (tester) async {
      await pumpStatisticsView(
        tester,
        habitResponse(type: type, monthlyScores: trailingTwelveMonths((index) => index / 11)),
      );

      final labels = renderedMonthLabels(tester);
      expect(labels.length, 12);
      expect(labels.toSet().length, labels.length);
      expect(
        labels,
        trailingTwelveMonths((_) => 0.0)
            .map((entry) => SharedTranslationKeys.getShortMonthKey(entry.key.month))
            .toList(),
      );
    });
  }

  testWidgets('Given the score chart When it renders Then the bottom axis steps once per data point', (tester) async {
    await pumpStatisticsView(
      tester,
      habitResponse(type: HabitType.bad, monthlyScores: trailingTwelveMonths((index) => index / 11)),
    );

    final chart = tester.widget<LineChart>(find.byType(LineChart));

    expect(chart.data.titlesData.bottomTitles.sideTitles.interval, 1);
  });
}
