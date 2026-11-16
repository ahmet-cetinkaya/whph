import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/widget/services/widget_service/helpers/widget_data_aggregator.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/presentation/ui/shared/services/filter_settings_manager.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/features/calendar/models/today_page_list_option_settings.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_list_option_settings.dart';
import 'package:whph/presentation/ui/features/habits/models/habit_list_option_settings.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/core/application/features/habits/models/habit_sort_fields.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';

import 'widget_data_aggregator_test.mocks.dart';

@GenerateMocks([Mediator, IContainer, FilterSettingsManager, IHabitRecordRepository])
void main() {
  late WidgetDataAggregator aggregator;
  late MockMediator mockMediator;
  late MockIContainer mockContainer;
  late MockFilterSettingsManager mockFilterSettingsManager;
  late MockIHabitRecordRepository mockHabitRecordRepository;

  setUp(() {
    mockMediator = MockMediator();
    mockContainer = MockIContainer();
    mockFilterSettingsManager = MockFilterSettingsManager();
    mockHabitRecordRepository = MockIHabitRecordRepository();

    provideDummy<IHabitRecordRepository>(mockHabitRecordRepository);

    when(mockContainer.resolve<IHabitRecordRepository>()).thenReturn(mockHabitRecordRepository);

    aggregator = WidgetDataAggregator(
      mediator: mockMediator,
      container: mockContainer,
      filterSettingsManager: mockFilterSettingsManager,
    );
  });

  test('getWidgetData should use correct page size and sort settings', () async {
    // Arrange
    final todaySettings = TodayPageListOptionSettings(selectedTagIds: ['tag1'], showNoTagsFilter: false);
    final taskSettings = TaskListOptionSettings(
      sortConfig: SortConfig<TaskSortFields>(
        orderOptions: [
          SortOptionWithTranslationKey(
            field: TaskSortFields.deadlineDate,
            translationKey: 'key',
            direction: SortDirection.asc,
          )
        ],
        useCustomOrder: false,
      ),
    );
    final habitSettings = HabitListOptionSettings(
      sortConfig: SortConfig<HabitSortFields>(
        orderOptions: [
          SortOptionWithTranslationKey(
            field: HabitSortFields.estimatedTime,
            translationKey: 'key',
            direction: SortDirection.desc,
          )
        ],
        useCustomOrder: false,
      ),
    );

    when(mockFilterSettingsManager.loadFilterSettings(settingKey: SettingKeys.todayPageListOptionsSettings))
        .thenAnswer((_) async => todaySettings.toJson());

    when(mockFilterSettingsManager.loadFilterSettings(settingKey: '${SettingKeys.tasksListOptionsSettings}_TODAY_PAGE'))
        .thenAnswer((_) async => taskSettings.toJson());

    when(mockFilterSettingsManager.loadFilterSettings(
            settingKey: '${SettingKeys.habitsListOptionsSettings}_TODAY_PAGE'))
        .thenAnswer((_) async => habitSettings.toJson());

    when(mockMediator.send<GetListTasksQuery, GetListTasksQueryResponse>(argThat(isA<GetListTasksQuery>())))
        .thenAnswer((_) async => GetListTasksQueryResponse(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 0));

    when(mockMediator.send<GetListHabitsQuery, GetListHabitsQueryResponse>(argThat(isA<GetListHabitsQuery>())))
        .thenAnswer((_) async => GetListHabitsQueryResponse(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 0));

    // Act
    await aggregator.getWidgetData();

    // Assert
    // Verify Tasks Query
    final taskQueryCapture =
        verify(mockMediator.send<GetListTasksQuery, GetListTasksQueryResponse>(captureThat(isA<GetListTasksQuery>())))
            .captured;
    final taskQuery = taskQueryCapture.first as GetListTasksQuery;

    expect(taskQuery.pageSize, 1000, reason: 'Task page size should be 1000');
    expect(taskQuery.sortBy?.length, 1);
    expect(taskQuery.sortBy?.first.field, TaskSortFields.deadlineDate);
    expect(taskQuery.sortBy?.first.direction, SortDirection.asc);
    expect(taskQuery.filterByTags, ['tag1'], reason: 'Task tag filter should be passed');

    // Verify Habits Query
    final habitQueryCapture = verify(
            mockMediator.send<GetListHabitsQuery, GetListHabitsQueryResponse>(captureThat(isA<GetListHabitsQuery>())))
        .captured;
    final habitQuery = habitQueryCapture.first as GetListHabitsQuery;

    expect(habitQuery.pageSize, 1000, reason: 'Habit page size should be 1000');
    expect(habitQuery.sortBy?.length, 1);
    expect(habitQuery.sortBy?.first.field, HabitSortFields.estimatedTime);
    expect(habitQuery.sortBy?.first.direction, SortDirection.desc);
    expect(habitQuery.filterByTags, ['tag1'], reason: 'Habit tag filter should be passed');
  });
}
