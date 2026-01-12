import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/domain/features/sync/models/desktop_sync_mode.dart';
import 'package:whph/infrastructure/desktop/features/sync/desktop_sync_service.dart';
import 'package:whph/presentation/ui/features/sync/pages/sync_devices_page/mixins/desktop_sync_mode_mixin.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

// Mocks
import 'package:whph/core/domain/features/settings/setting.dart';

// Mocks & Fakes
class MockMediator extends Mock implements Mediator {}

class FakeTranslationService extends Fake implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
}

class FakeSettingRepository extends Fake implements ISettingRepository {
  Setting? _setting;

  void setReturn(Setting? setting) {
    _setting = setting;
  }

  @override
  Future<Setting?> getByKey(String key) async {
    return _setting;
  }
}

class MockDesktopSyncService extends Mock implements DesktopSyncService {
  @override
  Future<void> switchToMode(DesktopSyncMode? mode) {
    return super.noSuchMethod(
      Invocation.method(#switchToMode, [mode]),
      returnValue: Future<void>.value(),
      returnValueForMissingStub: Future<void>.value(),
    );
  }
}

// Test Widget Helper
class TestDesktopSyncModeWidget extends StatefulWidget {
  final Mediator mediator;
  final ITranslationService translationService;
  final ISettingRepository settingRepository;
  final DesktopSyncService desktopSyncService;

  const TestDesktopSyncModeWidget({
    super.key,
    required this.mediator,
    required this.translationService,
    required this.settingRepository,
    required this.desktopSyncService,
  });

  @override
  TestDesktopSyncModeWidgetState createState() => TestDesktopSyncModeWidgetState();
}

class TestDesktopSyncModeWidgetState extends State<TestDesktopSyncModeWidget> with DesktopSyncModeMixin {
  @override
  Mediator get mediator => widget.mediator;
  @override
  ITranslationService get translationService => widget.translationService;
  @override
  ISettingRepository get settingRepository => widget.settingRepository;
  @override
  DesktopSyncService? get desktopSyncService => widget.desktopSyncService;

  bool _mockIsServerMode = false;
  @override
  bool get isServerMode => _mockIsServerMode;
  @override
  set isServerMode(bool value) => _mockIsServerMode = value;

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

void main() {
  late MockMediator mockMediator;
  late FakeTranslationService fakeTranslationService;
  late FakeSettingRepository fakeSettingRepository;
  late MockDesktopSyncService mockDesktopSyncService;

  setUp(() {
    mockMediator = MockMediator();
    fakeTranslationService = FakeTranslationService();
    fakeSettingRepository = FakeSettingRepository();
    fakeSettingRepository.setReturn(null); // Ensure it returns null
    mockDesktopSyncService = MockDesktopSyncService();
  });

  // Helper to pump widget
  Future<void> pumpTestWidget(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TestDesktopSyncModeWidget(
        mediator: mockMediator,
        translationService: fakeTranslationService,
        settingRepository: fakeSettingRepository,
        desktopSyncService: mockDesktopSyncService,
      ),
    ));
  }

  // Note: We cannot easily mock PlatformUtils.isDesktop since it's a static getter access
  // without a proper wrapper or if it's not designed for testing.
  // However, assuming we are running tests on a platform that might be considered desktop or we can try to rely on logic.
  // Actually, 'acore' package usually handles this. If this test runs on linux, isDesktop should be true.

  testWidgets('loadDesktopSyncModePreference requests server mode when no setting exists', (WidgetTester tester) async {
    // Arrange
    fakeSettingRepository.setReturn(null); // Ensure null is returned

    // Act
    await pumpTestWidget(tester);
    final state = tester.stateLike<TestDesktopSyncModeWidgetState>(find.byType(TestDesktopSyncModeWidget));

    // Trigger the load manually since initState might have run before we could intercept?
    // Actually the mixin methods are usually called in initState of the consuming page.
    // The mixin DOES NOT auto-call loadDesktopSyncModePreference in initState,
    // the consuming PAGE does. So we need to call it manually.
    await state!.loadDesktopSyncModePreference();

    // Assert
    // We expect it to default to server mode
    verify(mockDesktopSyncService.switchToMode(DesktopSyncMode.server)).called(1);
    expect(state.desktopSyncMode, DesktopSyncMode.server);
    expect(state.isServerMode, true);
  });
}

extension TesterExtensions on WidgetTester {
  T? stateLike<T>(Finder finder) {
    return state(finder) as T?;
  }
}
