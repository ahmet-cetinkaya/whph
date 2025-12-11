import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/presentation/ui/features/about/services/changelog_dialog_service.dart';
import 'package:whph/presentation/ui/features/about/services/abstraction/i_changelog_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

import 'changelog_dialog_service_test.mocks.dart';

@GenerateMocks([
  Mediator,
  IChangelogService,
  ITranslationService,
  GetSettingQueryResponse,
])
void main() {
  group('ChangelogDialogService', () {
    late ChangelogDialogService service;
    late MockMediator mockMediator;
    late MockIChangelogService mockChangelogService;
    late MockITranslationService mockTranslationService;

    setUp(() {
      mockMediator = MockMediator();
      mockChangelogService = MockIChangelogService();
      mockTranslationService = MockITranslationService();
      service = ChangelogDialogService(
        mockMediator,
        mockChangelogService,
        mockTranslationService,
      );
    });

    group('getCoreVersion', () {
      test('should extract core version from full version', () {
        // Act
        final result = service.getCoreVersion('0.18.0+65');

        // Assert
        expect(result, equals('0.18.0'));
      });

      test('should handle version without build number', () {
        // Act
        final result = service.getCoreVersion('0.18.0');

        // Assert
        expect(result, equals('0.18.0'));
      });

      test('should handle empty version', () {
        // Act
        final result = service.getCoreVersion('');

        // Assert
        expect(result, equals(''));
      });

      test('should handle null version', () {
        // Act
        final result = service.getCoreVersion(null);

        // Assert
        expect(result, equals(''));
      });

      test('should handle version with multiple plus signs', () {
        // Act
        final result = service.getCoreVersion('0.18.0+65+extra');

        // Assert
        expect(result, equals('0.18.0'));
      });
    });

    group('checkAndShowChangelogDialog', () {
      late BuildContext mockContext;

      setUp(() {
        mockContext = MockBuildContext();
        when(mockContext.locale).thenReturn(const Locale('en'));
        when(mockContext.mounted).thenReturn(true);
      });

      test('should not show dialog when version already shown', () async {
        // Arrange
        when(mockMediator.send<GetSettingQuery, GetSettingQueryResponse>(
          any,
        )).thenAnswer((_) async {
          final response = MockGetSettingQueryResponse();
          when(response.getValue<String>()).thenReturn('0.18.0');
          return response;
        });

        // Act
        await service.checkAndShowChangelogDialog(mockContext);

        // Assert
        verifyNever(mockChangelogService.fetchChangelog(any));
      });

      test('should not show dialog for first-time user', () async {
        // Arrange
        when(mockMediator.send<GetSettingQuery, GetSettingQueryResponse>(
          any,
        )).thenAnswer((_) async {
          final response = MockGetSettingQueryResponse();
          when(response.getValue<String>()).thenReturn(null);
          return response;
        });

        // Act
        await service.checkAndShowChangelogDialog(mockContext);

        // Assert
        verifyNever(mockChangelogService.fetchChangelog(any));
        verify(mockMediator.send(any)).captured
            .whereType<SaveSettingCommand>()
            .single
            .value
            .equals('0.18.0');
      });

      test('should show dialog when new version available', () async {
        // Arrange
        when(mockMediator.send<GetSettingQuery, GetSettingQueryResponse>(
          any,
        )).thenAnswer((_) async {
          final response = MockGetSettingQueryResponse();
          when(response.getValue<String>()).thenReturn('0.17.0');
          return response;
        });

        when(mockChangelogService.fetchChangelog('en')).thenAnswer(
          (_) async => ChangelogEntry(
            version: '0.18.0',
            content: '- New features',
          ),
        );

        // Act
        await service.checkAndShowChangelogDialog(mockContext);

        // Assert
        verify(mockChangelogService.fetchChangelog('en')).called(1);
        verify(mockMediator.send(any))
            .captured
            .whereType<SaveSettingCommand>()
            .length
            .equals(1);
      });

      test('should handle exceptions gracefully', () async {
        // Arrange
        when(mockMediator.send<GetSettingQuery, GetSettingQueryResponse>(
          any,
        )).thenThrow(Exception('Settings error'));

        // Act
        await service.checkAndShowChangelogDialog(mockContext);

        // Assert
        verify(mockMediator.send(any))
            .captured
            .whereType<SaveSettingCommand>()
            .length
            .equals(2); // One in catch block
      });
    });
  });
}

class MockBuildContext extends Mock implements BuildContext {
  @override
  Locale locale;

  MockBuildContext({this.locale = const Locale('en')});
}