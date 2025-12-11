import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:whph/presentation/ui/features/about/services/changelog_service.dart';
import 'package:whph/presentation/ui/features/about/services/abstraction/i_changelog_service.dart';

import 'changelog_service_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('ChangelogService', () {
    late ChangelogService service;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      service = ChangelogService();
    });

    test('should return changelog entry when successful fetch', () async {
      // Arrange
      const locale = 'en';
      const buildNumber = '65';

      // Act
      final result = await service.fetchChangelog(locale);

      // Assert
      expect(result, isNotNull);
      expect(result!.content, isNotEmpty);
      expect(result.version, isNotEmpty);
      expect(result.content, contains('Estimated time for tasks'));
    });

    test('should handle missing changelog gracefully', () async {
      // Arrange
      const locale = 'xx'; // Non-existent locale
      const buildNumber = '999'; // Non-existent build number

      // Act
      final result = await service.fetchChangelog(locale);

      // Assert
      // Since we have a fallback to English, we expect to get a result
      expect(result, isNotNull);
      expect(result!.content, isNotEmpty);
      expect(result.version, isNotEmpty);
    });

    test('should map locale codes correctly', () {
      // Test that the locale mapping covers all expected locales
      expect(ChangelogService.localeMapping, containsPair('en', 'en-US'));
      expect(ChangelogService.localeMapping, containsPair('cs', 'cs'));
      expect(ChangelogService.localeMapping, containsPair('da', 'da'));
      expect(ChangelogService.localeMapping, containsPair('de', 'de'));
      expect(ChangelogService.localeMapping, containsPair('el', 'el'));
      expect(ChangelogService.localeMapping, containsPair('es', 'es-ES'));
      expect(ChangelogService.localeMapping, containsPair('fi', 'fi'));
      expect(ChangelogService.localeMapping, containsPair('fr', 'fr-FR'));
      expect(ChangelogService.localeMapping, containsPair('it', 'it'));
      expect(ChangelogService.localeMapping, containsPair('ja', 'ja'));
      expect(ChangelogService.localeMapping, containsPair('ko', 'ko'));
      expect(ChangelogService.localeMapping, containsPair('nl', 'nl'));
      expect(ChangelogService.localeMapping, containsPair('no', 'no'));
      expect(ChangelogService.localeMapping, containsPair('pl', 'pl'));
      expect(ChangelogService.localeMapping, containsPair('pt', 'pt-PT'));
      expect(ChangelogService.localeMapping, containsPair('ro', 'ro'));
      expect(ChangelogService.localeMapping, containsPair('ru', 'ru'));
      expect(ChangelogService.localeMapping, containsPair('sl', 'sl'));
      expect(ChangelogService.localeMapping, containsPair('sv', 'sv'));
      expect(ChangelogService.localeMapping, containsPair('tr', 'tr'));
      expect(ChangelogService.localeMapping, containsPair('uk', 'uk'));
      expect(ChangelogService.localeMapping, containsPair('zh', 'zh-CN'));
    });

    test('should handle null locale gracefully', () async {
      // Arrange
      const locale = 'invalid-locale';

      // Act
      final result = await service.fetchChangelog(locale);

      // Assert
      // Should fallback to English
      expect(result, isNotNull);
    });
  });
}