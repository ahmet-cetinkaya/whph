import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/presentation/ui/features/about/services/changelog_service.dart';
import 'changelog_service_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('ChangelogService', () {
    late ChangelogService service;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      ChangelogService.clearCache();
      service = ChangelogService(client: mockClient);
    });

    test('should return changelog entry with formatted bullets when successful fetch', () async {
      // Arrange
      const locale = 'en';
      const rawContent = '• Estimated time for tasks';
      const expectedContent = '- Estimated time for tasks';
      when(mockClient.get(any, headers: anyNamed('headers'))).thenAnswer((_) async {
        return http.Response(rawContent, 200, headers: {
          'content-type': 'text/plain; charset=utf-8',
        });
      });

      // Act
      final result = await service.fetchChangelog(locale);

      // Assert
      expect(result, isNotNull);
      expect(result!.content, isNotEmpty);
      expect(result.version, isNotEmpty);
      expect(result.content, equals(expectedContent));
    });

    test('should handle missing changelog gracefully', () async {
      // Arrange
      const locale = 'xx'; // Non-existent locale
      const content = 'Fallback content';
      when(mockClient.get(any, headers: anyNamed('headers'))).thenAnswer((_) async => http.Response(content, 200));

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
      expect(ChangelogService.localeMapping, containsPair('cs', 'cs-CZ'));
      expect(ChangelogService.localeMapping, containsPair('da', 'da-DK'));
      expect(ChangelogService.localeMapping, containsPair('de', 'de-DE'));
      expect(ChangelogService.localeMapping, containsPair('el', 'el-GR'));
      expect(ChangelogService.localeMapping, containsPair('es', 'es-ES'));
      expect(ChangelogService.localeMapping, containsPair('fi', 'fi-FI'));
      expect(ChangelogService.localeMapping, containsPair('fr', 'fr-FR'));
      expect(ChangelogService.localeMapping, containsPair('it', 'it-IT'));
      expect(ChangelogService.localeMapping, containsPair('ja', 'ja-JP'));
      expect(ChangelogService.localeMapping, containsPair('ko', 'ko-KR'));
      expect(ChangelogService.localeMapping, containsPair('nl', 'nl-NL'));
      expect(ChangelogService.localeMapping, containsPair('no', 'no-NO'));
      expect(ChangelogService.localeMapping, containsPair('pl', 'pl-PL'));
      expect(ChangelogService.localeMapping, containsPair('pt', 'pt-PT'));
      expect(ChangelogService.localeMapping, containsPair('ro', 'ro'));
      expect(ChangelogService.localeMapping, containsPair('ru', 'ru-RU'));
      expect(ChangelogService.localeMapping, containsPair('sl', 'sl'));
      expect(ChangelogService.localeMapping, containsPair('sv', 'sv-SE'));
      expect(ChangelogService.localeMapping, containsPair('tr', 'tr-TR'));
      expect(ChangelogService.localeMapping, containsPair('uk', 'uk'));
      expect(ChangelogService.localeMapping, containsPair('zh', 'zh-CN'));
    });

    test('should handle null locale gracefully', () async {
      // Arrange
      const locale = 'invalid-locale';
      const content = 'Fallback content';
      when(mockClient.get(any, headers: anyNamed('headers'))).thenAnswer((_) async => http.Response(content, 200));

      // Act
      final result = await service.fetchChangelog(locale);

      // Assert
      // Should fallback to English
      expect(result, isNotNull);
    });
  });
}
