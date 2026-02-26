import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/presentation/ui/shared/services/theme_service/theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:acore/acore.dart';

import 'theme_service_test.mocks.dart';

// Test logger that discards all log messages
class TestLogger implements ILogger {
  const TestLogger();

  @override
  void debug(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void info(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void error(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void fatal(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
}

// Test ThemeService subclass to override system brightness
class TestThemeService extends ThemeService {
  Brightness _mockBrightness = Brightness.light;

  TestThemeService({required super.mediator, required super.logger});

  void setMockBrightness(Brightness brightness) {
    _mockBrightness = brightness;
  }

  @override
  Future<Brightness> getSystemBrightness() async {
    return _mockBrightness;
  }
}

@GenerateMocks([Mediator])
void main() {
  late TestThemeService themeService;
  late MockMediator mockMediator;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockMediator = MockMediator();
    themeService = TestThemeService(mediator: mockMediator, logger: TestLogger());
  });

  tearDown(() async {
    themeService.dispose();
    // Allow any pending microtasks to complete
    await Future.delayed(Duration.zero);
  });

  group('ThemeService', () {
    test('should update theme when system brightness changes and mode is auto', () async {
      // Arrange
      when(mockMediator.send<SaveSettingCommand, SaveSettingCommandResponse>(any))
          .thenAnswer((_) async => SaveSettingCommandResponse(
                id: 'test-id',
                createdDate: DateTime.now().toUtc(),
              ));

      await themeService.initialize();
      await themeService.setThemeMode(AppThemeMode.auto);

      // Verify initial state
      themeService.setMockBrightness(Brightness.light);
      await themeService.updateActualThemeMode();
      expect(themeService.currentThemeMode, AppThemeMode.auto);
      expect(themeService.themeData.brightness, Brightness.light);

      // Act: Simulate system brightness change
      themeService.setMockBrightness(Brightness.dark);
      themeService.didChangePlatformBrightness();

      // Wait for async operations (updateActualThemeMode and notifyThemeChanged)
      await Future.delayed(const Duration(milliseconds: 10));

      // Assert: The service should have updated to dark
      expect(themeService.themeData.brightness, Brightness.dark);
    });

    test('should NOT update theme when system brightness changes and mode is manual', () async {
      // Arrange
      when(mockMediator.send<SaveSettingCommand, SaveSettingCommandResponse>(any))
          .thenAnswer((_) async => SaveSettingCommandResponse(
                id: 'test-id',
                createdDate: DateTime.now().toUtc(),
              ));

      await themeService.initialize();
      await themeService.setThemeMode(AppThemeMode.dark);

      // Verify initial state is Dark
      expect(themeService.currentThemeMode, AppThemeMode.dark);
      expect(themeService.themeData.brightness, Brightness.dark);

      // Act: Simulate system brightness change (system goes light)
      themeService.setMockBrightness(Brightness.light);
      themeService.didChangePlatformBrightness();

      // Wait for async operations
      await Future.delayed(const Duration(milliseconds: 10));

      // Assert - should still be Dark (manual mode shouldn't change with system)
      expect(themeService.themeData.brightness, Brightness.dark);
    });
  });
}
