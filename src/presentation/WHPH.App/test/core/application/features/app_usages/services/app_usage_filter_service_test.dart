import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/core/application/features/app_usages/services/app_usage_filter_service.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_ignore_rule.dart';

import 'app_usage_filter_service_test.mocks.dart';

class TestAppUsageFilterService extends AppUsageFilterService {
  TestAppUsageFilterService(super.appUsageIgnoreRuleRepository);

  @override
  List<String> getSystemAppExclusions() {
    return ['com.android.systemui'];
  }
}

@GenerateMocks([IAppUsageIgnoreRuleRepository])
void main() {
  late AppUsageFilterService appUsageFilterService;
  late MockIAppUsageIgnoreRuleRepository mockAppUsageIgnoreRuleRepository;

  setUp(() {
    mockAppUsageIgnoreRuleRepository = MockIAppUsageIgnoreRuleRepository();
    appUsageFilterService = AppUsageFilterService(mockAppUsageIgnoreRuleRepository);
  });

  group('AppUsageFilterService', () {
    test('shouldExcludeApp returns true for empty appName', () async {
      // Act
      final result = await appUsageFilterService.shouldExcludeApp('');

      // Assert
      expect(result, isTrue);
    });

    test('shouldExcludeApp returns true if app is in ignore list', () async {
      // Arrange
      const appName = 'com.ignored.app';
      final ignoreRule = AppUsageIgnoreRule(
        id: '1',
        pattern: appName,
        createdDate: DateTime.now(),
      );
      when(mockAppUsageIgnoreRuleRepository.getAll()).thenAnswer((_) async => [ignoreRule]);

      // Act
      final result = await appUsageFilterService.shouldExcludeApp(appName);

      // Assert
      expect(result, isTrue);
    });

    test('shouldExcludeApp returns false if app is not in ignore list and not a system app', () async {
      // Arrange
      const appName = 'com.example.app';
      when(mockAppUsageIgnoreRuleRepository.getAll()).thenAnswer((_) async => []);

      // Act
      final result = await appUsageFilterService.shouldExcludeApp(appName);

      // Assert
      expect(result, isFalse);
    });

    test('shouldExcludeApp returns true for a system app', () async {
      // Arrange
      const systemAppName = 'com.android.systemui';
      when(mockAppUsageIgnoreRuleRepository.getAll()).thenAnswer((_) async => []);
      final service = TestAppUsageFilterService(mockAppUsageIgnoreRuleRepository);

      // Act
      final result = await service.shouldExcludeApp(systemAppName);

      // Assert
      expect(result, isTrue);
    });
  });
}
