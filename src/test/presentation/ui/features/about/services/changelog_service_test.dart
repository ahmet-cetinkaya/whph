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
      final response = '''
- New feature added
- Bug fixes
- Performance improvements
''';

      // Act
      final result = await service.fetchChangelog(locale);

      // Assert
      expect(result, isNotNull);
      expect(result!.content, contains('New feature added'));
      expect(result.version, isNotEmpty);
    });

    test('should handle missing changelog gracefully', () async {
      // Arrange
      const locale = 'xx'; // Non-existent locale
      const buildNumber = '999'; // Non-existent build number

      // Act
      final result = await service.fetchChangelog(locale);

      // Assert
      expect(result, isNull);
    });

    test('should map locale codes correctly', () {
      // Test that the locale mapping covers all expected locales
      expect(ChangelogService._localeMapping, containsPair('en', 'en-US'));
      expect(ChangelogService._localeMapping, containsPair('cs', 'cs'));
      expect(ChangelogService._localeMapping, containsPair('da', 'da'));
      expect(ChangelogService._localeMapping, containsPair('de', 'de'));
      expect(ChangelogService._localeMapping, containsPair('el', 'el'));
      expect(ChangelogService._localeMapping, containsPair('es', 'es-ES'));
      expect(ChangelogService._localeMapping, containsPair('fi', 'fi'));
      expect(ChangelogService._localeMapping, containsPair('fr', 'fr-FR'));
      expect(ChangelogService._localeMapping, containsPair('it', 'it'));
      expect(ChangelogService._localeMapping, containsPair('ja', 'ja'));
      expect(ChangelogService._localeMapping, containsPair('ko', 'ko'));
      expect(ChangelogService._localeMapping, containsPair('nl', 'nl'));
      expect(ChangelogService._localeMapping, containsPair('no', 'no'));
      expect(ChangelogService._localeMapping, containsPair('pl', 'pl'));
      expect(ChangelogService._localeMapping, containsPair('pt', 'pt-PT'));
      expect(ChangelogService._localeMapping, containsPair('ro', 'ro'));
      expect(ChangelogService._localeMapping, containsPair('ru', 'ru'));
      expect(ChangelogService._localeMapping, containsPair('sl', 'sl'));
      expect(ChangelogService._localeMapping, containsPair('sv', 'sv'));
      expect(ChangelogService._localeMapping, containsPair('tr', 'tr'));
      expect(ChangelogService._localeMapping, containsPair('uk', 'uk'));
      expect(ChangelogService._localeMapping, containsPair('zh', 'zh-CN'));
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