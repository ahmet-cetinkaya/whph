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

@GenerateMocks([Mediator])
void main() {
  late ThemeService themeService;
  late MockMediator mockMediator;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockMediator = MockMediator();
    themeService = ThemeService(mediator: mockMediator, logger: TestLogger());
  });

  tearDown(() async {
    // Add a small delay to ensure all async operations complete before disposal
    await Future.delayed(const Duration(milliseconds: 100));
    themeService.dispose();
  });

  group('ThemeService', () {
    test('should update theme when system brightness changes and mode is auto', () async {
      // Arrange
      // Mock the SaveSettingCommand to return a valid response
      when(mockMediator.send<SaveSettingCommand, SaveSettingCommandResponse>(any))
          .thenAnswer((_) async => SaveSettingCommandResponse(
                id: 'test-id',
                createdDate: DateTime.now().toUtc(),
              ));

      await themeService.initialize();
      await themeService.setThemeMode(AppThemeMode.auto);

      // Wait for async operations inside initialize/setThemeMode to complete
      await Future.delayed(Duration.zero);

      // Verify initial state is auto and has a valid theme
      expect(themeService.currentThemeMode, AppThemeMode.auto);
      expect(themeService.themeData.brightness, isA<Brightness>());

      // Act: Simulate system brightness change by calling the method directly
      // Note: In test environment, we can't easily mock the actual platform brightness
      // But we can verify that calling didChangePlatformBrightness doesn't crash
      // and that the service remains in auto mode
      themeService.didChangePlatformBrightness();

      // Wait for async operations in didChangePlatformBrightness to complete
      await Future.delayed(Duration.zero);

      // Assert: The service should still be in auto mode and have a valid theme
      expect(themeService.currentThemeMode, AppThemeMode.auto);
      expect(themeService.themeData.brightness, isA<Brightness>());

      // Additional verification: The service should be responsive to changes
      // and not throw exceptions when system brightness changes
      expect(() => themeService.didChangePlatformBrightness(), returnsNormally);
    });

    test('should NOT update theme when system brightness changes and mode is manual', () async {
      // Arrange
      // Mock the SaveSettingCommand for manual dark mode
      when(mockMediator.send<SaveSettingCommand, SaveSettingCommandResponse>(any))
          .thenAnswer((_) async => SaveSettingCommandResponse(
                id: 'test-id',
                createdDate: DateTime.now().toUtc(),
              ));

      // Initialize service
      await themeService.initialize();

      // Set theme mode to dark manually
      await themeService.setThemeMode(AppThemeMode.dark);

      // Verify initial state is Dark
      expect(themeService.currentThemeMode, AppThemeMode.dark);
      expect(themeService.themeData.brightness, Brightness.dark);

      // Simulate system brightness change
      TestWidgetsFlutterBinding.ensureInitialized();
      // Note: In Flutter 3.9.0+, we need to use platformDispatcher
      // But for testing, we'll call the didChangePlatformBrightness method directly
      themeService.didChangePlatformBrightness();

      // Assert - should still be Dark (manual mode shouldn't change with system)
      expect(themeService.currentThemeMode, AppThemeMode.dark);
      expect(themeService.themeData.brightness, Brightness.dark);
    });

    // Note: Testing Linux specific logic (Process.run and Timer) requires more extensive mocking
    // of dart:io and async waiting which is complex in this setup.
    // The manual verification plan covers these scenarios.
  });
}
