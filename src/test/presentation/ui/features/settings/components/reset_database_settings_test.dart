import 'package:acore/acore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/components/reset_database_settings.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

// Mocks
class FakeContainer implements IContainer {
  final Map<Type, dynamic> _services = {};

  void register<T>(T service) {
    _services[T] = service;
  }

  @override
  T resolve<T>({String? name}) {
    if (_services.containsKey(T)) {
      return _services[T] as T;
    }
    throw Exception('Service of type $T not registered');
  }

  @override
  bool isRegistered<T>({String? name}) => _services.containsKey(T);

  @override
  void unregister<T>({String? name}) => _services.remove(T);

  @override
  void dispose() {}

  @override
  void clear() => _services.clear();

  @override
  IContainer get instance => this;

  @override
  void registerSingleton<T>(T Function(IContainer) factory) {
    _services[T] = factory(this);
  }
}

class MockTranslationService extends Mock implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) {
    return key;
  }

  @override
  Widget wrapWithTranslations(Widget child) {
    return child;
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> changeLanguage(BuildContext context, String languageCode) async {}

  @override
  Future<void> changeLanguageWithoutNavigation(BuildContext context, String languageCode) async {}

  @override
  String getCurrentLanguage(BuildContext context) => 'en';
}

class MockAppDatabase extends Mock implements AppDatabase {
  bool resetCalled = false;

  @override
  Future<void> resetDatabase() async {
    resetCalled = true;
    return Future.value();
  }
}

void main() {
  late FakeContainer fakeContainer;
  late MockTranslationService mockTranslationService;
  late MockAppDatabase mockAppDatabase;

  setUp(() {
    fakeContainer = FakeContainer();
    mockTranslationService = MockTranslationService();
    mockAppDatabase = MockAppDatabase();

    // Setup global functions/vars
    container = fakeContainer;
    AppDatabase.setInstanceForTesting(mockAppDatabase);

    // Register mocks
    fakeContainer.register<ITranslationService>(mockTranslationService);
  });

  tearDown(() {
    AppDatabase.resetInstance();
  });

  testWidgets('Tapping outside Reset Database dialog should NOT trigger reset', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const ResetDatabaseSettings(),
        ),
      ),
    );

    // Act - Open Dialog
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle(); // Wait for dialog to open

    // Verify Dialog is open
    expect(find.text(SettingsTranslationKeys.resetDatabaseDialogTitle), findsOneWidget);

    // Act - Tap on the barrier (top left corner typically works for barrier)
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle(); // Wait for potential close

    // Assert
    // Verify dialog is STILL open (barrier dismiss disabled)
    expect(find.text(SettingsTranslationKeys.resetDatabaseDialogTitle), findsOneWidget);

    // Verify resetDatabase was NOT called
    expect(mockAppDatabase.resetCalled, isFalse, reason: 'resetDatabase should not be called');

    // Clean up
    await tester.tapAt(const Offset(10, 10));
  });

  testWidgets('Confirming Reset Database dialog SHOULD trigger reset', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const ResetDatabaseSettings(),
        ),
      ),
    );

    // Act - Open Dialog
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle(); // Wait for dialog to open

    // Act - Confirm
    final sliderFinder = find.byType(SwipeToConfirm);
    expect(sliderFinder, findsOneWidget);

    // Drag the arrow icon specifically
    final arrowFinder = find.byIcon(Icons.arrow_forward_rounded);

    // Drag all the way to the right
    await tester.drag(arrowFinder, const Offset(350, 0));
    await tester.pumpAndSettle();

    // Assert
    expect(mockAppDatabase.resetCalled, isTrue, reason: 'resetDatabase SHOULD be called when confirmed');
  });
}
