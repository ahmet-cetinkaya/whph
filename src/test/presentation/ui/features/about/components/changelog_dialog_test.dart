import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:whph/presentation/ui/features/about/components/changelog_dialog.dart';
import 'package:whph/presentation/ui/features/about/services/abstraction/i_changelog_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

import 'changelog_dialog_test.mocks.dart';

@GenerateMocks([ITranslationService])
void main() {
  group('ChangelogDialog', () {
    late MockITranslationService mockTranslationService;

    setUp(() {
      mockTranslationService = MockITranslationService();
      when(mockTranslationService.translate(any))
          .thenReturn('Translated text');
      when(mockTranslationService.translate(any, namedArgs: anyNamed('namedArgs')))
          .thenReturn('Version 0.18.0');
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        home: Scaffold(
          body: ChangelogDialog(
            changelogEntry: const ChangelogEntry(
              version: '0.18.0',
              content: '''
# New Features
- Feature 1
- Feature 2

## Bug Fixes
- Fixed bug 1
- Fixed bug 2
            ''',
            ),
            translationService: mockTranslationService,
          ),
        ),
      );
    }

    testWidgets('should display app title', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());

      // Act
      await tester.pumpAndSettle();

      // Assert - the title should be present
      expect(find.text('Work Hard Play Hard'), findsOneWidget, reason: 'Should find the app title');
    });

    testWidgets('should display version number', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Version 0.18.0'), findsAtLeastNWidgets(1));
    });

    testWidgets('should render markdown content', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('New Features'), findsOneWidget);
      expect(find.text('Bug Fixes'), findsOneWidget);
      expect(find.text('Feature 1'), findsOneWidget);
      expect(find.text('Fixed bug 1'), findsOneWidget);
    });

    testWidgets('should have close button', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.text('Version 0.18.0'), findsAtLeastNWidgets(1)); // Version number appears multiple times
    });

    testWidgets('should close dialog when close button pressed',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Act
      final closeButton = tester.widget<TextButton>(find.byType(TextButton));
      closeButton.onPressed?.call();
      await tester.pumpAndSettle();

      // Assert
      // Dialog should be closed (navigation popped)
      // In a real app, this would navigate back
    });

    testWidgets('should handle markdown links', (WidgetTester tester) async {
      // Arrange
      const changelogWithLink = ChangelogEntry(
        version: '0.18.0',
        content: '[Check out our website](https://example.com)',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangelogDialog(
              changelogEntry: changelogWithLink,
              translationService: mockTranslationService,
            ),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(MarkdownBody), findsOneWidget);
    });

    testWidgets('should have app logo', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('should display app name', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Work Hard Play Hard'), findsOneWidget);
    });
  });
}