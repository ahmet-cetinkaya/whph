import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure_shared/services/desktop_startup_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_args.dart';

void main() {
  group('DesktopStartupService', () {
    // Reset state before each test if possible, but the service is static.
    // We can just call initializeWithArgs again to overwrite state.

    test('should detect minimized argument', () {
      DesktopStartupService.initializeWithArgs([AppArgs.minimized]);
      expect(DesktopStartupService.shouldStartMinimized, true);
    });

    test('should detect sync argument', () {
      DesktopStartupService.initializeWithArgs([AppArgs.sync]);
      expect(DesktopStartupService.shouldStartSync, true);
      expect(DesktopStartupService.hasArgument(AppArgs.sync), true);
    });

    test('should handle multiple arguments', () {
      DesktopStartupService.initializeWithArgs([AppArgs.minimized, AppArgs.sync]);
      expect(DesktopStartupService.shouldStartMinimized, true);
      expect(DesktopStartupService.shouldStartSync, true);
    });

    test('should handle no arguments', () {
      DesktopStartupService.initializeWithArgs([]);
      expect(DesktopStartupService.shouldStartMinimized, false);
      expect(DesktopStartupService.shouldStartSync, false);
    });

    test('getStartupArguments should return correct list', () {
      DesktopStartupService.initializeWithArgs([AppArgs.sync]);
      final args = DesktopStartupService.getStartupArguments();
      expect(args, contains(AppArgs.sync));
      expect(args, isNot(contains(AppArgs.minimized)));
    });
  });
}
