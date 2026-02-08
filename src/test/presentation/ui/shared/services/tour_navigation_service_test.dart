import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:mockito/mockito.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/app_usages/pages/app_usage_view_page.dart';
import 'package:whph/presentation/ui/features/calendar/pages/today_page.dart';
import 'package:whph/presentation/ui/features/habits/pages/habits_page.dart';
import 'package:whph/presentation/ui/features/notes/pages/notes_page.dart';
import 'package:whph/presentation/ui/features/tags/pages/tags_page.dart';
import 'package:whph/presentation/ui/features/tasks/pages/tasks_page.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_tour_navigation_service.dart';
import 'package:whph/presentation/ui/shared/services/tour_navigation_service.dart';

// Mocks
class MockTranslationService extends Mock implements ITranslationService {
  @override
  String translate(String? key, {Map<String, dynamic>? namedArgs}) {
    return key ?? '';
  }
}

class TestMediator extends Mock implements Mediator {
  final Map<Type, Function> _handlers = {};

  void register<TRequest, TResponse>(Future<TResponse> Function(TRequest) handler) {
    _handlers[TRequest] = handler;
  }

  @override
  Future<TResponse> send<TRequest extends IRequest<TResponse>, TResponse>(TRequest? request) async {
    if (request == null) throw ArgumentError('Request cannot be null');

    final handler = _handlers[request.runtimeType];
    if (handler != null) {
      return await handler(request) as TResponse;
    }

    throw UnimplementedError('TestMediator: No handler registered for ${request.runtimeType}');
  }
}

class MockContainer extends Mock implements IContainer {
  @override
  IContainer get instance => this;

  final Map<Type, dynamic> _stubs = {};

  void stub<T>(T instance) {
    _stubs[T] = instance;
  }

  @override
  T resolve<T>() {
    if (_stubs.containsKey(T)) {
      return _stubs[T] as T;
    }

    if (T == ITranslationService) return MockTranslationService() as T;
    if (T == Mediator) return TestMediator() as T;

    try {
      return super.noSuchMethod(
        Invocation.method(#resolve, []),
        returnValue: null as T,
        returnValueForMissingStub: null as T,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  void registerSingleton<T>(T Function(IContainer) factory) {}

  @override
  bool isRegistered<T>() => false;

  @override
  void clear() {
    _stubs.clear();
  }
}

// Helper to create test app with necessary routes
Widget createTestApp() {
  return MaterialApp(
    navigatorKey: app_main.navigatorKey,
    initialRoute: '/',
    onGenerateRoute: (settings) {
      return MaterialPageRoute(
        builder: (context) {
          switch (settings.name) {
            case '/':
              return const Scaffold(body: Text('Home'));
            case TasksPage.route:
              return const Scaffold(body: Text('Tasks Page'));
            case HabitsPage.route:
              return const Scaffold(body: Text('Habits Page'));
            case TodayPage.route:
              return const Scaffold(body: Text('Today Page'));
            case TagsPage.route:
              return const Scaffold(body: Text('Tags Page'));
            case AppUsageViewPage.route:
              return const Scaffold(body: Text('App Usage Page'));
            case NotesPage.route:
              return const Scaffold(body: Text('Notes Page'));
            default:
              return const Scaffold(body: Text('Not Found'));
          }
        },
      );
    },
  );
}

void main() {
  late MockContainer mockContainer;
  late TestMediator testMediator;
  late MockTranslationService mockTranslationService;

  setUp(() {
    mockContainer = MockContainer();
    testMediator = TestMediator();
    mockTranslationService = MockTranslationService();

    // Configure responsive dialog helper for tests
    ResponsiveDialogHelper.configure(
      const ResponsiveDialogConfig(
        screenMediumBreakpoint: 600,
        containerBorderRadius: 12,
      ),
    );

    // Setup container mocks
    mockContainer.stub<ITranslationService>(mockTranslationService);
    mockContainer.stub<ITourNavigationService>(TourNavigationServiceImpl(testMediator));
    app_main.container = mockContainer;

    // Reset Navigation
    app_main.navigatorKey = GlobalKey<NavigatorState>();
  });

  group('TourNavigationService', () {
    testWidgets('startMultiPageTour navigates to first page (TasksPage)', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Configure mediator
      testMediator.register<GetSettingQuery, GetSettingQueryResponse?>((q) async => null);

      // Act
      // Initial context
      final homeContext = tester.element(find.text('Home'));
      await TourNavigationService.startMultiPageTour(homeContext, force: true);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Tasks Page'), findsOneWidget);
    });

    testWidgets('startMultiPageTour with force=true starts tour even if completed', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Configure mediator
      testMediator.register<GetSettingQuery, GetSettingQueryResponse?>((q) async {
        if (q.key == SettingKeys.tourCompleted) {
          return GetSettingQueryResponse(
            id: '1',
            createdDate: DateTime.now(),
            key: SettingKeys.tourCompleted,
            value: 'true',
            valueType: SettingValueType.bool,
          );
        }
        return null;
      });

      // Act
      final homeContext = tester.element(find.text('Home'));
      await TourNavigationService.startMultiPageTour(homeContext, force: true);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Tasks Page'), findsOneWidget);
    });

    testWidgets('onPageTourCompleted navigates to next page', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      testMediator.register<GetSettingQuery, GetSettingQueryResponse?>((q) async => null);

      // Start tour
      final homeContext = tester.element(find.text('Home'));
      await TourNavigationService.startMultiPageTour(homeContext, force: true);
      await tester.pumpAndSettle();

      // Currently at TasksPage (index 0)
      expect(find.text('Tasks Page'), findsOneWidget);

      // Complete page 0 using CONTEXT OF THE NEW PAGE
      final tasksPageContext = tester.element(find.text('Tasks Page'));
      await TourNavigationService.onPageTourCompleted(tasksPageContext);
      await tester.pumpAndSettle();

      // Should be at HabitsPage (index 1)
      expect(find.text('Habits Page'), findsOneWidget);
    });

    testWidgets('Complete full tour navigates to TodayPage', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      testMediator.register<GetSettingQuery, GetSettingQueryResponse?>((q) async => null);
      testMediator.register<SaveSettingCommand, SaveSettingCommandResponse>(
          (c) async => SaveSettingCommandResponse(id: '1', createdDate: DateTime.now()));

      // Start tour first
      final homeContext = tester.element(find.text('Home'));
      await TourNavigationService.startMultiPageTour(homeContext, force: true);
      await tester.pumpAndSettle();

      // Complete pages sequentially, ALWAYS GETTING FRESH CONTEXT

      // Complete pages sequentially
      // The tour has 6 pages: Tasks(0), Habits(1), Today(2), Tags(3), AppUsage(4), Notes(5)
      // Loop iterates 6 times.
      // Iteration 1 (Tasks): Completes Tasks -> Navigates to Habits.
      // ...
      // Iteration 6 (Notes): Completes Notes -> Navigates to TodayPage (Completion).

      final pages = [
        'Tasks Page', // index 0 -> 1
        'Habits Page', // index 1 -> 2
        'Today Page', // index 2 -> 3
        'Tags Page', // index 3 -> 4
        'App Usage Page', // index 4 -> 5
        'Notes Page' // index 5 -> Finish (TodayPage)
      ];

      for (final pageText in pages) {
        // Verify current page is visible
        expect(find.text(pageText), findsOneWidget);

        // Get context of current page to trigger completion
        final currentContext = tester.element(find.text(pageText));
        await TourNavigationService.onPageTourCompleted(currentContext);
        await tester.pumpAndSettle();
      }

      // After the last step (Notes Page), the service navigates to TodayPage.
      // Verify we are at TodayPage.
      expect(find.text('Today Page'), findsOneWidget);
    });
  });
}
