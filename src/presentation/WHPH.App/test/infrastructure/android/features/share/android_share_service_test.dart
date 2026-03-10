import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/android/features/share/android_share_service.dart';

void main() {
  group('AndroidShareService', () {
    group('extractTitleFromText', () {
      test('should extract first line as title when text has multiple lines', () {
        const text = 'First line\nSecond line\nThird line';
        final (title, description) = AndroidShareService.extractTitleFromText(text);

        expect(title, equals('First line'));
        expect(description, equals('Second line\nThird line'));
      });

      test('should return entire text as title when single line and short', () {
        const text = 'Single line text';
        final (title, description) = AndroidShareService.extractTitleFromText(text);

        expect(title, equals('Single line text'));
        expect(description, isNull);
      });

      test('should truncate title at 50 characters with ellipsis', () {
        const text = 'This is a very long title that exceeds the fifty character limit for titles';
        final (title, description) = AndroidShareService.extractTitleFromText(text);

        expect(title.length, equals(53)); // 50 + '...'
        expect(title, contains('...'));
        expect(title.startsWith('This is a very long title that exceeds the fi'), isTrue);
      });

      test('should handle empty first line', () {
        const text = '\nSecond line starts here';
        final (title, description) = AndroidShareService.extractTitleFromText(text);

        // When trimmed first line is empty, finds first non-empty line as title
        expect(title, equals('Second line starts here'));
        expect(description, isNull);
      });

      test('should handle text with exactly 50 characters', () {
        const text = '12345678901234567890123456789012345678901234567890'; // Exactly 50 chars
        final (title, description) = AndroidShareService.extractTitleFromText(text);

        expect(title, equals(text));
        expect(description, isNull);
      });

      test('should handle text with 51 characters', () {
        const text = '123456789012345678901234567890123456789012345678901'; // Exactly 51 chars
        final (title, description) = AndroidShareService.extractTitleFromText(text);

        expect(title.length, equals(53)); // 50 + '...'
        expect(title, contains('...'));
        expect(description, isNull);
      });

      test('should handle text with leading and trailing whitespace', () {
        const text = '  \n  Title with spaces  \n  Description here  ';
        final (title, description) = AndroidShareService.extractTitleFromText(text);

        // When trimmed first line is empty, finds first non-empty line as title
        expect(title, equals('Title with spaces'));
        expect(description, equals('Description here'));
      });

      test('should handle text with multiple consecutive newlines', () {
        const text = 'Title\n\n\nDescription';
        final (title, description) = AndroidShareService.extractTitleFromText(text);

        expect(title, equals('Title'));
        // text.substring(5).trim() = '\n\n\nDescription'.trim() = 'Description'
        expect(description, equals('Description'));
      });

      test('should handle very long text with newlines', () {
        // 'Very long title that exceeds fifty character limit' is exactly 50 characters
        const text = 'Very long title that exceeds fifty character limit\nAnd a very long description';
        final (title, description) = AndroidShareService.extractTitleFromText(text);

        // Title is exactly 50 chars, so no truncation
        expect(title.length, equals(50));
        expect(title, contains('Very long title'));
        expect(description, isNotNull);
      });

      test('should handle empty string', () {
        const text = '';
        final (title, description) = AndroidShareService.extractTitleFromText(text);

        expect(title, equals(''));
        expect(description, isNull);
      });

      test('should handle single newline', () {
        const text = '\n';
        final (title, description) = AndroidShareService.extractTitleFromText(text);

        // When first line after trim is empty and no non-empty lines found, returns empty string
        expect(title, equals(''));
        expect(description, isNull);
      });

      test('should handle text with only whitespace', () {
        const text = '   \n   \n   ';
        final (title, description) = AndroidShareService.extractTitleFromText(text);

        // When all lines are whitespace-only, returns empty string
        expect(title, equals(''));
        expect(description, isNull);
      });

      test('should preserve text content in title when under limit', () {
        const text = 'Buy groceries\nMilk\nEggs\nBread';
        final (title, description) = AndroidShareService.extractTitleFromText(text);

        expect(title, equals('Buy groceries'));
        expect(description, equals('Milk\nEggs\nBread'));
      });

      test('should handle shared URL scenario', () {
        const text = 'https://example.com/very/long/url/path/that/exceeds/limit?query=value&another=value';
        final (title, description) = AndroidShareService.extractTitleFromText(text);

        expect(title.length, equals(53)); // 50 + '...'
        expect(title, contains('...'));
      });

      test('should handle shared email scenario', () {
        const text = 'Meeting with John\nDiscuss the Q1 roadmap and deliverables\nTime: 2pm';
        final (title, description) = AndroidShareService.extractTitleFromText(text);

        expect(title, equals('Meeting with John'));
        expect(description, equals('Discuss the Q1 roadmap and deliverables\nTime: 2pm'));
      });

      test('should return null description when remainder is empty after trim', () {
        const text = 'Title only\n\n'; // Title followed by empty lines
        final (title, description) = AndroidShareService.extractTitleFromText(text);

        expect(title, equals('Title only'));
        expect(description, isNull);
      });

      test('should handle title exactly at 50 character boundary', () {
        const text = '12345678901234567890123456789012345678901234567890\nDescription text';
        final (title, description) = AndroidShareService.extractTitleFromText(text);

        expect(title, equals('12345678901234567890123456789012345678901234567890'));
        expect(description, equals('Description text'));
      });

      test('should handle very long first line with no newlines', () {
        const text =
            'This is a very long title with no newlines that definitely exceeds the fifty character maximum limit';
        final (title, description) = AndroidShareService.extractTitleFromText(text);

        expect(title.length, equals(53)); // 50 + '...'
        expect(title, contains('...'));
        expect(description, isNull);
      });
    });
  });
}
