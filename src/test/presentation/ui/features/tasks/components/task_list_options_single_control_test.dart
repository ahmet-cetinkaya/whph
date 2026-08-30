import 'dart:convert';

import 'package:acore/acore.dart' hide Container;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/application/features/habits/models/habit_sort_fields.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/habits/components/habit_list_options.dart';
import 'package:whph/presentation/ui/features/habits/models/habit_list_style.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_list_options.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_view_mode.dart';
import 'package:whph/presentation/ui/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/ui/shared/components/group_dialog_button.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class MockTranslationService extends Mock implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
}

class FakeThemeService extends Fake implements IThemeService {
  @override
  Color get primaryColor => Colors.blue;
  @override
  Color get surface1 => Colors.white;
  @override
  Color get surface2 => Colors.grey;
  @override
  Color get textColor => Colors.black;
  @override
  Color get secondaryTextColor => Colors.grey;
}

class MockLogger extends Mock implements ILogger {
  @override
  void info(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
  @override
  void debug(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
  @override
  void warning(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
  @override
  void error(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
  @override
  void fatal(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
}

/// Serves whatever persisted settings JSON the test seeds, so legacy payloads
/// can be driven through the real load path.
class FakeMediator extends Fake implements Mediator {
  Map<String, dynamic>? savedSettings;

  FakeMediator({this.savedSettings});

  @override
  Future<TResponse> send<TRequest extends IRequest<TResponse>, TResponse extends Object?>(TRequest request) async {
    if (request is GetSettingQuery) {
      if (savedSettings == null) return null as TResponse;
      final settingQuery = request as GetSettingQuery;
      return GetSettingQueryResponse(
        id: 'setting-id',
        createdDate: DateTime.now(),
        key: settingQuery.key ?? '',
        value: jsonEncode(savedSettings),
        valueType: SettingValueType.json,
      ) as TResponse;
    }
    if (request is GetListTagsQuery) {
      return GetListTagsQueryResponse(
        items: const [],
        totalItemCount: 0,
        pageIndex: 0,
        pageSize: 100,
      ) as TResponse;
    }
    return null as TResponse;
  }
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

SortConfig<TaskSortFields> _taskConfig({required bool useCustomOrder, bool enableGrouping = false}) =>
    SortConfig<TaskSortFields>(
      orderOptions: const [
        SortOptionWithTranslationKey(
          field: TaskSortFields.plannedDate,
          direction: SortDirection.asc,
          translationKey: 'tasks.planned_date',
        ),
      ],
      useCustomOrder: useCustomOrder,
      enableGrouping: enableGrouping,
      groupOption: enableGrouping
          ? const SortOptionWithTranslationKey(
              field: TaskSortFields.status,
              direction: SortDirection.asc,
              translationKey: 'tasks.status',
            )
          : null,
    );

void main() {
  late FakeContainer fakeContainer;
  late FakeMediator fakeMediator;

  void setUpContainer({Map<String, dynamic>? savedSettings}) {
    fakeContainer = FakeContainer();
    app_main.container = fakeContainer;
    fakeMediator = FakeMediator(savedSettings: savedSettings);
    fakeContainer.register<Mediator>(fakeMediator);
    fakeContainer.register<ITranslationService>(MockTranslationService());
    fakeContainer.register<IThemeService>(FakeThemeService());
    fakeContainer.register<ILogger>(MockLogger());
  }

  Future<void> pumpTaskOptions(
    WidgetTester tester, {
    required SortConfig<TaskSortFields> sortConfig,
    required TaskViewMode viewMode,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TaskListOptions(
          sortConfig: sortConfig,
          viewMode: viewMode,
          onSortChange: (_) {},
          showSaveButton: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('TaskListOptions single custom-sort control', () {
    setUp(() => setUpContainer());

    testWidgets('renders no layout-toggle button when custom sort is on in list mode', (tester) async {
      await pumpTaskOptions(tester, sortConfig: _taskConfig(useCustomOrder: true), viewMode: TaskViewMode.list);

      // The removed toggle was the only FilterIconButton this configuration
      // could render; a reorder/layout icon reappearing means it came back.
      final filterButtons = tester.widgetList<FilterIconButton>(find.byType(FilterIconButton));
      expect(
        filterButtons.where((b) => b.icon == Icons.reorder || b.icon == Icons.reorder_outlined),
        isEmpty,
      );
    });

    testWidgets('grouping control stays active in list mode when custom sort is on', (tester) async {
      await pumpTaskOptions(
        tester,
        sortConfig: _taskConfig(useCustomOrder: true, enableGrouping: true),
        viewMode: TaskViewMode.list,
      );

      final groupButton = tester.widget<GroupDialogButton<TaskSortFields>>(
        find.byType(GroupDialogButton<TaskSortFields>),
      );
      expect(groupButton.isDisabled, isFalse);
    });

    testWidgets('grouping control stays active in board mode with custom sort on', (tester) async {
      await pumpTaskOptions(
        tester,
        sortConfig: _taskConfig(useCustomOrder: true, enableGrouping: true),
        viewMode: TaskViewMode.board,
      );

      final groupButton = tester.widget<GroupDialogButton<TaskSortFields>>(
        find.byType(GroupDialogButton<TaskSortFields>),
      );
      expect(groupButton.isDisabled, isFalse);
    });

    testWidgets('grouping control stays active in list mode when custom sort is off', (tester) async {
      await pumpTaskOptions(
        tester,
        sortConfig: _taskConfig(useCustomOrder: false, enableGrouping: true),
        viewMode: TaskViewMode.list,
      );

      final groupButton = tester.widget<GroupDialogButton<TaskSortFields>>(
        find.byType(GroupDialogButton<TaskSortFields>),
      );
      expect(groupButton.isDisabled, isFalse);
    });
  });

  group('TaskListOptions legacy persisted settings', () {
    testWidgets('loads settings containing a legacy forceOriginalLayout key without throwing', (tester) async {
      setUpContainer(savedSettings: <String, dynamic>{
        'showNoTagsFilter': false,
        'showCompletedTasks': false,
        'search': null,
        'forceOriginalLayout': true,
        'showSubTasks': false,
        'viewMode': 'list',
        'sortConfig': {
          'orderOptions': [
            {'field': 'createdDate', 'direction': 'desc', 'translationKey': 'shared.created_date'},
          ],
          'useCustomOrder': true,
          'enableGrouping': false,
        },
      });

      SortConfig<TaskSortFields>? loadedConfig;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TaskListOptions(
            sortConfig: _taskConfig(useCustomOrder: false),
            viewMode: TaskViewMode.list,
            onSortChange: (config) => loadedConfig = config,
            showSaveButton: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Custom sort alone comes back; the legacy key is ignored, not honoured.
      expect(loadedConfig?.useCustomOrder, isTrue);
    });
  });

  group('HabitListOptions single custom-sort control', () {
    setUp(() => setUpContainer());

    SortConfig<HabitSortFields> habitConfig({
      required bool useCustomOrder,
      bool showCustomSortIndicator = true,
    }) =>
        SortConfig<HabitSortFields>(
          orderOptions: const [
            SortOptionWithTranslationKey(
              field: HabitSortFields.name,
              direction: SortDirection.asc,
              translationKey: 'shared.name',
            ),
          ],
          useCustomOrder: useCustomOrder,
          enableGrouping: true,
          showCustomSortIndicator: showCustomSortIndicator,
        );

    /// Pumps the today-page configuration, which is the only one that offers
    /// the view-style toggle.
    Future<void> pumpHabitOptions(
      WidgetTester tester, {
      required bool useCustomOrder,
      bool showCustomSortIndicator = true,
      ValueChanged<HabitListStyle>? onHabitListStyleChange,
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HabitListOptions(
            sortConfig: habitConfig(
              useCustomOrder: useCustomOrder,
              showCustomSortIndicator: showCustomSortIndicator,
            ),
            onSortChange: (_) {},
            onHabitListStyleChange: onHabitListStyleChange ?? (_) {},
            habitListStyle: HabitListStyle.grid,
            showViewStyleOption: true,
            showSaveButton: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    /// The style toggle renders whichever icon matches the current style, so
    /// every style icon must be absent for the control to be gone.
    Iterable<FilterIconButton> styleToggles(WidgetTester tester) =>
        tester.widgetList<FilterIconButton>(find.byType(FilterIconButton)).where((button) =>
            button.icon == Icons.grid_view || button.icon == Icons.view_list || button.icon == Icons.calendar_month);

    testWidgets('hides the view-style toggle while the custom-sort indicator is shown', (tester) async {
      await pumpHabitOptions(tester, useCustomOrder: true);

      expect(styleToggles(tester), isEmpty);
    });

    testWidgets('shows the view-style toggle when the custom-sort indicator is hidden', (tester) async {
      HabitListStyle? selectedStyle;
      await pumpHabitOptions(
        tester,
        useCustomOrder: true,
        showCustomSortIndicator: false,
        onHabitListStyleChange: (style) => selectedStyle = style,
      );

      expect(styleToggles(tester), isNotEmpty);
      await tester.tap(find.byIcon(Icons.grid_view));
      expect(selectedStyle, HabitListStyle.list);
    });

    testWidgets('shows the view-style toggle when custom sort is off', (tester) async {
      await pumpHabitOptions(tester, useCustomOrder: false);

      expect(styleToggles(tester), isNotEmpty);
    });

    testWidgets('keeps grouping active when custom sort is on', (tester) async {
      await pumpHabitOptions(tester, useCustomOrder: true);

      final groupButton = tester.widget<GroupDialogButton<HabitSortFields>>(
        find.byType(GroupDialogButton<HabitSortFields>),
      );
      expect(groupButton.isDisabled, isFalse);
    });

    testWidgets('keeps grouping active when custom sort is off', (tester) async {
      await pumpHabitOptions(tester, useCustomOrder: false);

      final groupButton = tester.widget<GroupDialogButton<HabitSortFields>>(
        find.byType(GroupDialogButton<HabitSortFields>),
      );
      expect(groupButton.isDisabled, isFalse);
    });
  });
}
