import 'package:acore/acore.dart' hide Container;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' show UiDensity;
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/habits/components/habits_list.dart';
import 'package:whph/presentation/ui/features/habits/models/habit_list_style.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/features/tags/services/time_data_service.dart';
import 'package:whph/presentation/ui/shared/components/load_more_button.dart';
import 'package:whph/presentation/ui/shared/enums/pagination_mode.dart';
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
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
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

/// Serves a fixed habit table the way the real query does: the repository
/// slices by `pageIndex * pageSize`, then the handler may drop rows in Dart
/// (e.g. `excludeCompletedForDate`) while `totalItemCount` stays the
/// unfiltered repository count and `pageIndex`/`pageSize` are echoed back.
class PagingHabitsMediator extends Fake implements Mediator {
  PagingHabitsMediator(this.ids, {this.dropAfterSlice});

  final List<String> ids;
  final bool Function(String id)? dropAfterSlice;

  /// Every `GetListHabitsQuery` received, as `(pageIndex, pageSize)`.
  final List<(int, int)> queryLog = [];

  @override
  Future<R> send<T extends IRequest<R>, R extends Object?>(T request) async {
    final Object message = request;
    if (message is GetListHabitsQuery) {
      queryLog.add((message.pageIndex, message.pageSize));
      final start = (message.pageIndex * message.pageSize).clamp(0, ids.length);
      final end = (start + message.pageSize).clamp(0, ids.length);
      final slice = ids.sublist(start, end);
      final kept = dropAfterSlice == null ? slice : slice.where((id) => !dropAfterSlice!(id)).toList();
      return GetListHabitsQueryResponse(
        items: [
          for (final id in kept)
            HabitListItem(
              id: id,
              name: id,
              order: String.fromCharCode('F'.codeUnitAt(0) + ids.indexOf(id)),
            ),
        ],
        totalItemCount: ids.length,
        pageIndex: message.pageIndex,
        pageSize: message.pageSize,
      ) as R;
    }
    if (message is GetListHabitRecordsQuery) {
      return GetListHabitRecordsQueryResponse(
        items: const [],
        totalItemCount: 0,
        pageIndex: 0,
        pageSize: 0,
      ) as R;
    }
    throw UnimplementedError('Unhandled request: ${request.runtimeType}');
  }
}

List<String> _habitIds(int count) => [for (var i = 0; i < count; i++) 'habit-${i.toString().padLeft(2, '0')}'];

void main() {
  late PagingHabitsMediator mediator;
  late MockHabitsService habitsService;

  void setUpContainer(List<String> ids, {bool Function(String id)? dropAfterSlice}) {
    final fakeContainer = FakeContainer();
    app_main.container = fakeContainer;
    mediator = PagingHabitsMediator(ids, dropAfterSlice: dropAfterSlice);
    habitsService = MockHabitsService();

    final translationService = MockTranslationService();
    fakeContainer.register<Mediator>(mediator);
    fakeContainer.register<ITranslationService>(translationService);
    fakeContainer.register<HabitsService>(habitsService);
    fakeContainer.register<ISoundManagerService>(MockSoundManagerService());
    fakeContainer.register<TimeDataService>(MockTimeDataService());
    fakeContainer.register<IThemeService>(FakeThemeService());
    fakeContainer.register<ILogger>(MockLogger());

    ErrorHelper.initialize(translationService);
  }

  void pinSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('delayed refresh does not restore stale offset', (tester) async {
    pinSurface(tester);
    setUpContainer(_habitIds(60));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HabitsList(
          useParentScroll: false,
          isThreeStateEnabled: true,
          paginationMode: PaginationMode.infinityScroll,
          style: HabitListStyle.grid,
          onClickHabit: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Initial load plus the viewport-fill auto-loads for a 400x800 surface.
    expect(mediator.queryLog, [(0, 10), (1, 10), (2, 10), (3, 10)]);

    final controller = tester.state<HabitsListState>(find.byType(HabitsList)).scrollController;
    expect(controller.position.maxScrollExtent, greaterThan(150));

    // A: the offset at the moment the delayed refresh is requested.
    controller.jumpTo(20);
    await tester.pumpAndSettle();
    final offsetA = controller.position.pixels;
    expect(offsetA, closeTo(20, 1));

    habitsService.onHabitRecordAdded.value = 'habit-00';
    await tester.pump();

    // B: where the user scrolls to and stays while the refresh is pending.
    controller.jumpTo(140);
    await tester.pumpAndSettle();
    final offsetB = controller.position.pixels;
    expect((offsetB - offsetA).abs(), greaterThan(100), reason: 'B must differ meaningfully from A');

    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();

    // The delayed refresh must have actually run (a pageIndex 0 reload).
    expect(mediator.queryLog.last.$1, 0);
    expect(
      controller.position.pixels,
      closeTo(offsetB, 1),
      reason: 'expected offset B ($offsetB) to be kept; stale offset A was $offsetA',
    );
  });

  testWidgets('today shape filtered paging reaches every kept habit', (tester) async {
    pinSurface(tester);
    final ids = _habitIds(23);
    // Drops the whole second page (positions 5-9) plus a few scattered rows:
    // 8 of 23 rows, about a third.
    final dropped = {...ids.sublist(5, 10), ids[2], ids[13], ids[21]};
    final kept = ids.where((id) => !dropped.contains(id)).toList();
    setUpContainer(ids, dropAfterSlice: dropped.contains);

    // Mirrors the Today page: a sliver HabitsList inside a CustomScrollView.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            HabitsList(
              pageSize: 5,
              excludeCompletedForDate: DateTime(2026, 9, 27),
              paginationMode: PaginationMode.loadMore,
              style: HabitListStyle.grid,
              useSliver: true,
              showDoneOverlayWhenEmpty: true,
              onClickHabit: (_) {},
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(mediator.queryLog, [(0, 5)]);

    final loadMore = find.byType(LoadMoreButton, skipOffstage: false);
    for (var i = 0; i < 20 && loadMore.evaluate().isNotEmpty; i++) {
      await tester.ensureVisible(loadMore);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: loadMore, matching: find.byType(InkWell)).first);
      await tester.pumpAndSettle();
    }

    expect(find.byType(LoadMoreButton, skipOffstage: false), findsNothing);

    for (final id in kept) {
      expect(find.text(id, skipOffstage: false), findsOneWidget, reason: '$id should be rendered exactly once');
    }
    for (final id in dropped) {
      expect(find.text(id, skipOffstage: false), findsNothing, reason: '$id was filtered out');
    }

    final pageIndexes = mediator.queryLog.map((q) => q.$1).toList();
    expect(pageIndexes.length, greaterThan(1), reason: 'load more must have fetched further pages');
    for (var i = 1; i < pageIndexes.length; i++) {
      expect(pageIndexes[i], greaterThan(pageIndexes[i - 1]), reason: 'query log $pageIndexes repeats a page');
    }
  });
}
