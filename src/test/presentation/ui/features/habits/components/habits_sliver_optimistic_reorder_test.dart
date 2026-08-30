import 'package:acore/acore.dart' hide Container;
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/habits/commands/update_habit_order_command.dart';
import 'package:whph/core/application/features/habits/models/habit_sort_fields.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' show UiDensity;
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/habits/components/habit_card/habit_card.dart';
import 'package:whph/presentation/ui/features/habits/components/habits_list.dart';
import 'package:whph/presentation/ui/shared/components/load_more_button.dart';
import 'package:whph/presentation/ui/features/habits/models/habit_list_style.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/features/tags/services/time_data_service.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/error_helper.dart';

class MockSoundManagerService extends Mock implements ISoundManagerService {}

class MockTimeDataService extends Mock implements TimeDataService {}

class MockHabitsService extends Mock implements HabitsService {
  @override
  final ValueNotifier<String?> onHabitCreated = ValueNotifier(null);
  @override
  final ValueNotifier<String?> onHabitUpdated = ValueNotifier(null);
  @override
  final ValueNotifier<String?> onHabitDeleted = ValueNotifier(null);
  @override
  final ValueNotifier<String?> onHabitRecordAdded = ValueNotifier(null);
  @override
  final ValueNotifier<String?> onHabitRecordRemoved = ValueNotifier(null);
}

class MockTranslationService extends Mock implements ITranslationService {
  MockTranslationService([this.translations = const {}]);

  final Map<String, String> translations;

  @override
  String translate(String key, {Map<String, String>? namedArgs}) => translations[key] ?? key;
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

class FakeThemeService extends Fake implements IThemeService {
  @override
  Color get primaryColor => Colors.blue;
  @override
  Color get surface0 => Colors.white;
  @override
  Color get surface1 => Colors.white;
  @override
  Color get surface2 => Colors.grey;
  @override
  Color get surface3 => Colors.grey;
  @override
  Color get textColor => Colors.black;
  @override
  Color get secondaryTextColor => Colors.grey;
  @override
  Color get darkTextColor => Colors.black;
  @override
  UiDensity get currentUiDensity => UiDensity.normal;
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

/// Serves habits in a caller-controlled order and records reorder commands,
/// applying each one the way the real handler would so a follow-up query
/// reflects the persisted result.
class ReorderMediator extends Fake implements Mediator {
  ReorderMediator(this.order, {this.archived = const {}, this.totalItemCount, this.groupNameOf});

  List<String> order;
  final Set<String> archived;
  final int? totalItemCount;

  /// Mirrors the real query, which fills `groupName` from the request's
  /// primary sort field regardless of whether the UI renders group headers.
  final String? Function(String id)? groupNameOf;
  final List<UpdateHabitOrderCommand> commands = [];

  @override
  Future<TResponse> send<TRequest extends IRequest<TResponse>, TResponse extends Object?>(TRequest request) async {
    if (request is GetListHabitsQuery) {
      return GetListHabitsQueryResponse(
        items: [
          for (final (index, id) in order.indexed)
            HabitListItem(
              id: id,
              name: id,
              archivedDate: archived.contains(id) ? DateTime(2020) : null,
              groupName: groupNameOf?.call(id),
              isGroupNameTranslatable: groupNameOf != null,
              // Canonical, well-spaced base-62 ranks so the widget does not
              // trigger its "orders need normalization" repair path.
              order: String.fromCharCode('F'.codeUnitAt(0) + index * 5),
            ),
        ],
        totalItemCount: totalItemCount ?? order.length,
        pageIndex: 0,
        pageSize: order.length,
      ) as TResponse;
    }
    if (request is UpdateHabitOrderCommand) {
      final command = request as UpdateHabitOrderCommand;
      commands.add(command);
      final next = List<String>.from(order)..remove(command.habitId);
      int insertAt;
      if (command.afterHabitId != null && next.contains(command.afterHabitId)) {
        insertAt = next.indexOf(command.afterHabitId!);
      } else if (command.beforeHabitId != null && next.contains(command.beforeHabitId)) {
        insertAt = next.indexOf(command.beforeHabitId!) + 1;
      } else {
        insertAt = command.targetIndex;
      }
      next.insert(insertAt.clamp(0, next.length), command.habitId);
      order = next;
      return UpdateHabitOrderResponse(command.habitId, command.habitId) as TResponse;
    }
    if (request is GetListHabitRecordsQuery) {
      return GetListHabitRecordsQueryResponse(
        items: const [],
        totalItemCount: 0,
        pageIndex: 0,
        pageSize: 0,
      ) as TResponse;
    }
    throw UnimplementedError('Unhandled request: ${request.runtimeType}');
  }
}

void main() {
  late FakeContainer fakeContainer;
  late ReorderMediator mediator;

  void setUpContainer(
    List<String> order, {
    Set<String> archived = const {},
    int? totalItemCount,
    String? Function(String id)? groupNameOf,
    Map<String, String> translations = const {},
  }) {
    fakeContainer = FakeContainer();
    app_main.container = fakeContainer;
    mediator = ReorderMediator(order, archived: archived, totalItemCount: totalItemCount, groupNameOf: groupNameOf);

    final translationService = MockTranslationService(translations);
    fakeContainer.register<Mediator>(mediator);
    fakeContainer.register<ITranslationService>(translationService);
    fakeContainer.register<HabitsService>(MockHabitsService());
    fakeContainer.register<ISoundManagerService>(MockSoundManagerService());
    fakeContainer.register<TimeDataService>(MockTimeDataService());
    fakeContainer.register<IThemeService>(FakeThemeService());
    fakeContainer.register<ILogger>(MockLogger());

    ErrorHelper.initialize(translationService);
  }

  Future<void> pumpSliverHabitList(
    WidgetTester tester, {
    bool showCustomSortIndicator = true,
    SortConfig<HabitSortFields>? sortConfig,
    HabitListStyle style = HabitListStyle.list,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            HabitsList(
              // Mirrors the today page: sliver mode, list style, reordering on.
              sortConfig: sortConfig ??
                  SortConfig<HabitSortFields>(
                    orderOptions: const [],
                    useCustomOrder: true,
                    enableGrouping: false,
                    showCustomSortIndicator: showCustomSortIndicator,
                  ),
              style: style,
              enableReordering: true,
              useSliver: true,
              onClickHabit: (_) {},
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  List<String> renderedOrder(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .where((s) => s.startsWith('habit-'))
      .toList();

  testWidgets('custom sort preserves calendar card style', (tester) async {
    setUpContainer(['habit-calendar']);
    await pumpSliverHabitList(tester, style: HabitListStyle.calendar);

    expect(tester.widget<HabitCard>(find.byType(HabitCard)).style, HabitListStyle.calendar);
  });

  testWidgets('visible custom-sort indicators force grid preference into list cards', (tester) async {
    setUpContainer(['habit-a']);
    await pumpSliverHabitList(tester, style: HabitListStyle.grid);

    expect(tester.widget<HabitCard>(find.byType(HabitCard)).style, HabitListStyle.list);
  });

  testWidgets('hidden custom-sort indicators preserve the grid preference', (tester) async {
    setUpContainer(['habit-a']);
    await pumpSliverHabitList(
      tester,
      style: HabitListStyle.grid,
      showCustomSortIndicator: false,
    );

    expect(tester.widget<HabitCard>(find.byType(HabitCard)).style, HabitListStyle.grid);
  });

  testWidgets('optimistic reorder is visible immediately, before the refresh lands', (tester) async {
    setUpContainer(['habit-a', 'habit-b', 'habit-c', 'habit-d']);
    await pumpSliverHabitList(tester);

    expect(renderedOrder(tester), ['habit-a', 'habit-b', 'habit-c', 'habit-d']);

    final state = tester.state<State<HabitsList>>(find.byType(HabitsList)) as dynamic;

    // Drop habit-a between habit-b and habit-c (pre-removal index 2).
    state.onSliverReorderForTest(0, 2);
    await tester.pump();

    expect(
      renderedOrder(tester),
      ['habit-b', 'habit-a', 'habit-c', 'habit-d'],
      reason: 'optimistic reorder must be rendered immediately after the drop',
    );
  });

  testWidgets('dropped position survives the post-command refresh', (tester) async {
    setUpContainer(['habit-a', 'habit-b', 'habit-c', 'habit-d']);
    await pumpSliverHabitList(tester);

    final state = tester.state<State<HabitsList>>(find.byType(HabitsList)) as dynamic;
    state.onSliverReorderForTest(0, 2);
    await tester.pumpAndSettle();

    expect(mediator.commands, hasLength(1));
    expect(renderedOrder(tester), ['habit-b', 'habit-a', 'habit-c', 'habit-d']);
  });

  testWidgets('parent setState during reorder does not revert the dropped position', (tester) async {
    setUpContainer(['habit-a', 'habit-b', 'habit-c', 'habit-d']);

    // Reproduces the today page wiring: the parent rebuilds itself from
    // onReorderComplete while the reorder is still settling.
    final sortConfig = SortConfig<HabitSortFields>(
      orderOptions: const [],
      useCustomOrder: true,
      enableGrouping: false,
    );

    late StateSetter rebuildParent;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            rebuildParent = setState;
            return CustomScrollView(
              slivers: [
                HabitsList(
                  sortConfig: sortConfig,
                  style: HabitListStyle.grid,
                  enableReordering: true,
                  useSliver: true,
                  onClickHabit: (_) {},
                  onReorderComplete: () => setState(() {}),
                ),
              ],
            );
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final state = tester.state<State<HabitsList>>(find.byType(HabitsList)) as dynamic;
    state.onSliverReorderForTest(0, 2);
    rebuildParent(() {});
    await tester.pumpAndSettle();

    expect(mediator.commands, hasLength(1));
    expect(renderedOrder(tester), ['habit-b', 'habit-a', 'habit-c', 'habit-d']);
  });

  testWidgets('archived habits do not desync reorder indices', (tester) async {
    // The today page does not filter archived habits out, and the habit card
    // passes dragIndex: null for archived entries while they still occupy a
    // slot in the reorderable list.
    setUpContainer(
      ['habit-a', 'habit-b', 'habit-c', 'habit-d'],
      archived: {'habit-b'},
    );
    await pumpSliverHabitList(tester);

    final state = tester.state<State<HabitsList>>(find.byType(HabitsList)) as dynamic;

    // Drop habit-a past habit-b so the archived entry sits between the
    // moved item and its destination.
    state.onSliverReorderForTest(0, 2);
    await tester.pumpAndSettle();

    expect(mediator.commands, hasLength(1));
    expect(renderedOrder(tester), ['habit-b', 'habit-a', 'habit-c', 'habit-d']);
  });

  testWidgets('REAL GESTURE: dragging the handle down moves the habit', (tester) async {
    setUpContainer(['habit-a', 'habit-b', 'habit-c', 'habit-d']);
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSliverHabitList(tester);

    expect(renderedOrder(tester), ['habit-a', 'habit-b', 'habit-c', 'habit-d']);

    final handles = find.byIcon(Icons.drag_handle);
    expect(handles, findsNWidgets(4), reason: 'each habit needs a drag handle');

    // Grab habit-a's handle and drag it down past habit-b.
    final start = tester.getCenter(handles.at(0));
    final rowHeight = tester.getCenter(handles.at(1)).dy - start.dy;

    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveBy(Offset(0, rowHeight * 0.6));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(Offset(0, rowHeight * 0.6));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(mediator.commands, hasLength(1), reason: 'a real drag must persist a reorder');
    expect(renderedOrder(tester), ['habit-b', 'habit-a', 'habit-c', 'habit-d']);
  });

  testWidgets('REAL GESTURE with a load-more row present (today page shape)', (tester) async {
    // The today page passes pageSize: 5 and more habits exist, so a
    // load-more row sits inside the reorderable list occupying an index.
    setUpContainer(
      ['habit-a', 'habit-b', 'habit-c', 'habit-d', 'habit-e'],
      totalItemCount: 20,
    );
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSliverHabitList(tester);

    expect(find.byType(LoadMoreButton), findsOneWidget,
        reason: 'this test is only meaningful with a trailing load-more row');

    final handles = find.byIcon(Icons.drag_handle);
    final start = tester.getCenter(handles.at(0));
    final rowHeight = tester.getCenter(handles.at(1)).dy - start.dy;

    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveBy(Offset(0, rowHeight * 0.6));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(Offset(0, rowHeight * 0.6));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(mediator.commands, hasLength(1));
    expect(renderedOrder(tester), ['habit-b', 'habit-a', 'habit-c', 'habit-d', 'habit-e']);
  });

  testWidgets('reorders when the query returns group names while grouping is suppressed', (tester) async {
    // The today page keeps its saved sort fields while custom order is on, so
    // the query still fills groupName (here: first letter of the name). The
    // list renders one ungrouped list, so the reorder lookup must agree with
    // how the list was actually built, not with the item's groupName.
    setUpContainer(
      ['habit-a', 'habit-b', 'habit-c', 'habit-d'],
      groupNameOf: (id) => id.substring('habit-'.length).toUpperCase(),
    );
    await pumpSliverHabitList(tester);

    expect(renderedOrder(tester), ['habit-a', 'habit-b', 'habit-c', 'habit-d']);

    final state = tester.state<State<HabitsList>>(find.byType(HabitsList)) as dynamic;
    state.onSliverReorderForTest(0, 2);
    await tester.pumpAndSettle();

    expect(mediator.commands, hasLength(1), reason: 'the drop must persist instead of being silently dropped');
    expect(renderedOrder(tester), ['habit-b', 'habit-a', 'habit-c', 'habit-d']);
  });

  group('hidden custom-sort indicator', () {
    testWidgets('REAL GESTURE: a whole-card long press reorders with no handle present', (tester) async {
      setUpContainer(['habit-a', 'habit-b', 'habit-c', 'habit-d']);
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpSliverHabitList(tester, showCustomSortIndicator: false);

      expect(renderedOrder(tester), ['habit-a', 'habit-b', 'habit-c', 'habit-d']);
      expect(find.byIcon(Icons.drag_handle), findsNothing, reason: 'no handle may exist to grab');

      final cards = find.byType(HabitCard);
      final start = tester.getCenter(cards.at(0));
      final rowHeight = tester.getCenter(cards.at(1)).dy - start.dy;

      // Press the card body itself, hold past the long-press delay, then drag.
      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveBy(Offset(0, rowHeight * 0.6));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(Offset(0, rowHeight * 0.6));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(mediator.commands, hasLength(1), reason: 'a whole-card long-press drag must persist a reorder');
      expect(renderedOrder(tester), ['habit-b', 'habit-a', 'habit-c', 'habit-d']);
    });

    testWidgets('REAL GESTURE: a short whole-card drag does not reorder', (tester) async {
      // Discriminates the delayed listener from a plain one: without the
      // long-press hold the same movement must scroll, never reorder.
      setUpContainer(['habit-a', 'habit-b', 'habit-c', 'habit-d']);
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpSliverHabitList(tester, showCustomSortIndicator: false);

      final cards = find.byType(HabitCard);
      final start = tester.getCenter(cards.at(0));
      final rowHeight = tester.getCenter(cards.at(1)).dy - start.dy;

      final gesture = await tester.startGesture(start);
      await gesture.moveBy(Offset(0, rowHeight * 0.6));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(Offset(0, rowHeight * 0.6));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(mediator.commands, isEmpty);
      expect(renderedOrder(tester), ['habit-a', 'habit-b', 'habit-c', 'habit-d']);
    });
  });

  group('grouped reorder is group-local', () {
    /// Renders two groups: header(alpha), a1, a2, header(beta), b1, b2.
    /// Visual indices: 0 header, 1 a1, 2 a2, 3 header, 4 b1, 5 b2.
    Future<void> pumpGroupedHabitList(WidgetTester tester) async {
      setUpContainer(
        ['habit-a1', 'habit-a2', 'habit-b1', 'habit-b2'],
        groupNameOf: (id) => id.startsWith('habit-a') ? 'alpha' : 'beta',
      );

      await pumpSliverHabitList(
        tester,
        sortConfig: SortConfig<HabitSortFields>(
          orderOptions: const [
            SortOptionWithTranslationKey(
              field: HabitSortFields.tag,
              direction: SortDirection.asc,
              translationKey: 'shared.tags',
            ),
          ],
          useCustomOrder: true,
          enableGrouping: true,
          groupOption: const SortOptionWithTranslationKey(
            field: HabitSortFields.tag,
            direction: SortDirection.asc,
            translationKey: 'shared.tags',
          ),
        ),
      );

      expect(find.text('alpha'), findsOneWidget, reason: 'this test is only meaningful with rendered group headers');
      expect(find.text('beta'), findsOneWidget);
    }

    testWidgets('a drop inside the source group is accepted', (tester) async {
      await pumpGroupedHabitList(tester);

      final state = tester.state<State<HabitsList>>(find.byType(HabitsList)) as dynamic;

      // Move a1 (visual 1) past a2 (pre-removal newIndex 3, the slot just
      // after the group's last item) — still inside alpha.
      state.onSliverReorderForTest(1, 3);
      await tester.pumpAndSettle();

      expect(mediator.commands, hasLength(1));
      expect(mediator.commands.single.habitId, 'habit-a1');
      expect(renderedOrder(tester), ['habit-a2', 'habit-a1', 'habit-b1', 'habit-b2']);
    });

    testWidgets('a drop past the source group into another group is ignored', (tester) async {
      await pumpGroupedHabitList(tester);

      final state = tester.state<State<HabitsList>>(find.byType(HabitsList)) as dynamic;

      // Move a1 (visual 1) down into beta's span (pre-removal newIndex 5). If
      // cross-group drops were merely clamped, this would still issue a
      // reorder command for a position the user never dragged to.
      state.onSliverReorderForTest(1, 5);
      await tester.pumpAndSettle();

      expect(mediator.commands, isEmpty);
      expect(renderedOrder(tester), ['habit-a1', 'habit-a2', 'habit-b1', 'habit-b2']);
    });

    testWidgets('headers follow translated labels while items stay stable inside each group', (tester) async {
      setUpContainer(
        ['habit-a1', 'habit-a2', 'habit-z1', 'habit-z2'],
        groupNameOf: (id) => id.startsWith('habit-a') ? 'group.a' : 'group.z',
        translations: const {'group.a': 'Zulu', 'group.z': 'Alpha'},
      );

      await pumpSliverHabitList(
        tester,
        sortConfig: SortConfig<HabitSortFields>(
          orderOptions: const [
            SortOptionWithTranslationKey(
              field: HabitSortFields.tag,
              direction: SortDirection.asc,
              translationKey: 'shared.tags',
            ),
          ],
          useCustomOrder: true,
          enableGrouping: true,
          groupOption: const SortOptionWithTranslationKey(
            field: HabitSortFields.tag,
            direction: SortDirection.asc,
            translationKey: 'shared.tags',
          ),
        ),
      );

      final alphaY = tester.getCenter(find.text('Alpha')).dy;
      final zuluY = tester.getCenter(find.text('Zulu')).dy;
      expect(alphaY, lessThan(zuluY), reason: 'headers must sort by their displayed labels, not raw group keys');
      expect(renderedOrder(tester), ['habit-z1', 'habit-z2', 'habit-a1', 'habit-a2']);
    });
  });
}
