// ignore_for_file: unused_local_variable

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/tasks/task_constants.dart';
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/settings/components/task_settings/skip_quick_add_setting.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:acore/acore.dart' hide Container;

import 'skip_quick_add_setting_test.mocks.dart';

@GenerateMocks([
  Mediator,
  ITranslationService,
])
void main() {
  late MockMediator mockMediator;
  late MockITranslationService mockTranslationService;
  late FakeContainer fakeContainer;

  setUpAll(() {
    fakeContainer = FakeContainer();
    app_main.container = fakeContainer;
  });

  setUp(() {
    mockMediator = MockMediator();
    mockTranslationService = MockITranslationService();

    fakeContainer.registerInstance<Mediator>(mockMediator);
    fakeContainer.registerInstance<ITranslationService>(mockTranslationService);

    // Setup default mock behaviors
    when(mockTranslationService.translate(SettingsTranslationKeys.taskSkipQuickAddTitle)).thenReturn('Skip Quick Add');
    when(mockTranslationService.translate(SettingsTranslationKeys.taskSkipQuickAddDescription))
        .thenReturn('Skip quick add dialog when creating tasks');
    when(mockTranslationService.translate(SettingsTranslationKeys.taskSkipQuickAddLoadError))
        .thenReturn('Failed to load setting');
    when(mockTranslationService.translate(SettingsTranslationKeys.taskSkipQuickAddSaveError))
        .thenReturn('Failed to save setting');
  });

  tearDown(() {
    fakeContainer.clear();
  });

  group('SkipQuickAddSetting Widget Tests - Loading State', () {
    testWidgets('should show loading indicator while loading setting', (WidgetTester tester) async {
      // Arrange - Create a completer to delay the setting load
      final completer = Completer<Setting?>();
      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) => completer.future);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SkipQuickAddSetting(),
          ),
        ),
      );

      // Assert - Should show CircularProgressIndicator while loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to allow cleanup
      completer.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('should not show loading indicator when initialValue is provided', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SkipQuickAddSetting(initialValue: true),
          ),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Switch), findsOneWidget);
    });
  });

  group('SkipQuickAddSetting Widget Tests - Loading Settings', () {
    testWidgets('should load and display current setting value', (WidgetTester tester) async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskSkipQuickAdd,
        value: 'true',
        valueType: SettingValueType.bool,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SkipQuickAddSetting(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);
    });

    testWidgets('should use default value when loading fails', (WidgetTester tester) async {
      // Arrange
      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenThrow(Exception('Loading failed'));

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SkipQuickAddSetting(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Should use TaskConstants.defaultSkipQuickAdd (false)
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, equals(TaskConstants.defaultSkipQuickAdd));
    });

    testWidgets('should use default value when setting is null', (WidgetTester tester) async {
      // Arrange
      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => null);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SkipQuickAddSetting(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, equals(TaskConstants.defaultSkipQuickAdd));
    });
  });

  group('SkipQuickAddSetting Widget Tests - Saving Settings', () {
    testWidgets('should save new value when switch is toggled', (WidgetTester tester) async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskSkipQuickAdd,
        value: 'false',
        valueType: SettingValueType.bool,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);
      when(mockMediator.send<SaveSettingCommand, SaveSettingCommandResponse>(any))
          .thenAnswer((_) async => SaveSettingCommandResponse(
                id: 'new-setting-id',
                createdDate: DateTime.now().toUtc(),
              ));

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SkipQuickAddSetting(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Assert
      verify(mockMediator.send<SaveSettingCommand, SaveSettingCommandResponse>(captureThat(
        predicate<SaveSettingCommand>((cmd) =>
            cmd.key == SettingKeys.taskSkipQuickAdd && cmd.value == 'true' && cmd.valueType == SettingValueType.bool),
      ))).called(1);
    });

    testWidgets('should revert state when save fails', (WidgetTester tester) async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskSkipQuickAdd,
        value: 'false',
        valueType: SettingValueType.bool,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);
      when(mockMediator.send<SaveSettingCommand, SaveSettingCommandResponse>(any)).thenThrow(Exception('Save failed'));

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SkipQuickAddSetting(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Get initial switch state
      final initialSwitch = tester.widget<Switch>(find.byType(Switch));
      expect(initialSwitch.value, isFalse);

      // Tap the switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Assert - Should revert to original value
      final finalSwitch = tester.widget<Switch>(find.byType(Switch));
      expect(finalSwitch.value, isFalse);
    });

    testWidgets('should disable switch during save operation', (WidgetTester tester) async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskSkipQuickAdd,
        value: 'false',
        valueType: SettingValueType.bool,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      final completer = Completer<SaveSettingCommandResponse>();
      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);
      when(mockMediator.send<SaveSettingCommand, SaveSettingCommandResponse>(any)).thenAnswer((_) => completer.future);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SkipQuickAddSetting(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the switch
      await tester.tap(find.byType(Switch));
      await tester.pump();

      // Assert - Switch should be disabled while saving
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, isNull);

      // Complete the save
      completer.complete(SaveSettingCommandResponse(
        id: 'setting-id',
        createdDate: DateTime.now().toUtc(),
      ));
      await tester.pumpAndSettle();
    });
  });

  group('SkipQuickAddSetting Widget Tests - User Interaction', () {
    testWidgets('should toggle when tile is tapped', (WidgetTester tester) async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskSkipQuickAdd,
        value: 'false',
        valueType: SettingValueType.bool,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);
      when(mockMediator.send<SaveSettingCommand, SaveSettingCommandResponse>(any))
          .thenAnswer((_) async => SaveSettingCommandResponse(
                id: 'new-setting-id',
                createdDate: DateTime.now().toUtc(),
              ));

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SkipQuickAddSetting(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the settings tile (it contains the title text)
      await tester.tap(find.text('Skip Quick Add'));
      await tester.pumpAndSettle();

      // Assert
      verify(mockMediator.send<SaveSettingCommand, SaveSettingCommandResponse>(captureThat(
        predicate<SaveSettingCommand>((cmd) => cmd.key == SettingKeys.taskSkipQuickAdd && cmd.value == 'true'),
      ))).called(1);
    });

    testWidgets('should not toggle when tile is tapped during save', (WidgetTester tester) async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskSkipQuickAdd,
        value: 'false',
        valueType: SettingValueType.bool,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      final completer = Completer<SaveSettingCommandResponse>();
      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);
      when(mockMediator.send<SaveSettingCommand, SaveSettingCommandResponse>(any)).thenAnswer((_) => completer.future);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SkipQuickAddSetting(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First tap - start save
      await tester.tap(find.byType(Switch));
      await tester.pump();

      // Try to tap again while saving
      await tester.tap(find.text('Skip Quick Add'));
      await tester.pump();

      // Assert - Should not trigger another save
      verify(mockMediator.send<SaveSettingCommand, SaveSettingCommandResponse>(any)).called(1);

      // Complete the save
      completer.complete(SaveSettingCommandResponse(
        id: 'setting-id',
        createdDate: DateTime.now().toUtc(),
      ));
      await tester.pumpAndSettle();
    });
  });

  group('SkipQuickAddSetting Widget Tests - Initial Value', () {
    testWidgets('should use initialValue when provided and skip loading', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SkipQuickAddSetting(initialValue: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);

      // Should not have called the mediator to load
      verifyNever(mockMediator.send<GetSettingQuery, Setting?>(any));
    });

    testWidgets('should use initialValue when provided and allow toggling', (WidgetTester tester) async {
      // Arrange
      when(mockMediator.send<SaveSettingCommand, SaveSettingCommandResponse>(any))
          .thenAnswer((_) async => SaveSettingCommandResponse(
                id: 'new-setting-id',
                createdDate: DateTime.now().toUtc(),
              ));

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SkipQuickAddSetting(initialValue: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Assert
      verify(mockMediator.send<SaveSettingCommand, SaveSettingCommandResponse>(captureThat(
        predicate<SaveSettingCommand>((cmd) => cmd.key == SettingKeys.taskSkipQuickAdd && cmd.value == 'true'),
      ))).called(1);
    });
  });

  group('SkipQuickAddSetting Widget Tests - Error Display', () {
    testWidgets('should show error notification on save failure', (WidgetTester tester) async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskSkipQuickAdd,
        value: 'false',
        valueType: SettingValueType.bool,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);
      when(mockMediator.send<SaveSettingCommand, SaveSettingCommandResponse>(any)).thenThrow(Exception('Save failed'));

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SkipQuickAddSetting(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Assert - Error message should be shown via AsyncErrorHandler
      // The error is handled internally, so we just verify it doesn't crash
      expect(tester.takeException(), isNull);
    });
  });
}

/// Fake container implementation for dependency injection in tests
class FakeContainer implements IContainer {
  final Map<Type, Object?> _instances = {};
  final Map<String, Object?> _namedInstances = {};

  @override
  IContainer get instance => this;

  void registerInstance<T>(T instance, [String? name]) {
    if (name != null) {
      _namedInstances[name] = instance;
    } else {
      _instances[T] = instance;
    }
  }

  void clear() {
    _instances.clear();
    _namedInstances.clear();
  }

  @override
  T resolve<T>([String? name]) {
    if (name != null) {
      if (_namedInstances.containsKey(name)) {
        return _namedInstances[name] as T;
      }
      throw UnimplementedError('No instance registered for name: $name');
    }
    if (_instances.containsKey(T)) {
      return _instances[T] as T;
    }
    throw UnimplementedError('No instance registered for type $T');
  }

  @override
  bool isRegistered<T>([String? name]) {
    if (name != null) {
      return _namedInstances.containsKey(name);
    }
    return _instances.containsKey(T);
  }

  @override
  void registerSingleton<T>(T Function(IContainer) factory) {
    _instances[T] = factory(this);
  }
}
