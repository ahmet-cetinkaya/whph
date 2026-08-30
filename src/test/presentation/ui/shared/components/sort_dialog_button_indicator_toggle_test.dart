import 'package:acore/acore.dart' hide Container;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' show UiDensity;
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/shared/components/sort_dialog_button.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class MockTranslationService extends Mock implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
}

class FakeThemeService extends Fake implements IThemeService {
  @override
  Color get primaryColor => Colors.blue;
  @override
  Color get surface1 => Colors.white;
  @override
  Color get surface2 => Colors.grey;
  @override
  Color get textColor => Colors.black;
  @override
  Color get secondaryTextColor => Colors.grey;
  @override
  UiDensity get currentUiDensity => UiDensity.normal;
}

class FakeContainer extends Fake implements IContainer {
  final Map<Type, dynamic> _registrations = {};

  void register<T>(dynamic instance) => _registrations[T] = instance;

  @override
  T resolve<T>([String? name]) {
    if (_registrations.containsKey(T)) return _registrations[T] as T;
    throw Exception('Service setup missing for type $T');
  }
}

/// Carries a distinct value in every field the toggle must NOT touch, so an
/// over-broad copyWith is observable rather than silently passing.
SortConfig<TaskSortFields> _config({required bool showCustomSortIndicator}) => SortConfig<TaskSortFields>(
      orderOptions: const [
        SortOptionWithTranslationKey(
          field: TaskSortFields.priority,
          direction: SortDirection.desc,
          translationKey: 'tasks.priority',
        ),
      ],
      useCustomOrder: true,
      enableGrouping: true,
      groupOption: const SortOptionWithTranslationKey(
        field: TaskSortFields.status,
        direction: SortDirection.asc,
        translationKey: 'tasks.status',
      ),
      customTagSortOrder: const ['tag-1', 'tag-2'],
      showCustomSortIndicator: showCustomSortIndicator,
    );

void main() {
  setUp(() {
    final fakeContainer = FakeContainer();
    app_main.container = fakeContainer;
    fakeContainer.register<ITranslationService>(MockTranslationService());
    fakeContainer.register<IThemeService>(FakeThemeService());
  });

  /// Opens the sort dialog and returns the configs handed back to the caller.
  Future<List<SortConfig<TaskSortFields>>> openDialog(
    WidgetTester tester, {
    required SortConfig<TaskSortFields> config,
  }) async {
    final received = <SortConfig<TaskSortFields>>[];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SortDialogButton<TaskSortFields>(
          tooltip: 'shared.sort.sort',
          availableOptions: const [
            SortOptionWithTranslationKey(
              field: TaskSortFields.priority,
              direction: SortDirection.desc,
              translationKey: 'tasks.priority',
            ),
          ],
          config: config,
          defaultConfig: config,
          onConfigChanged: received.add,
          showCustomOrderOption: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();

    return received;
  }

  Finder indicatorToggle() => find.byKey(const ValueKey('custom_sort_indicator_toggle'));

  /// The eye badge renders inside the toggle, so scope the lookup to it —
  /// otherwise an unrelated eye icon elsewhere could satisfy the assertion.
  IconData badgeIcon(WidgetTester tester) => tester
      .widget<Icon>(find.descendant(
        of: indicatorToggle(),
        matching: find.byKey(const ValueKey('custom_sort_indicator_badge')),
      ))
      .icon!;

  testWidgets('indicator visibility control uses the same drag handle icon as list items', (tester) async {
    await openDialog(tester, config: _config(showCustomSortIndicator: true));

    final baseIcons = tester
        .widgetList<Icon>(find.descendant(
          of: indicatorToggle(),
          matching: find.byType(Icon),
        ))
        .where((icon) => icon.key != const ValueKey('custom_sort_indicator_badge'));

    expect(baseIcons.single.icon, Icons.drag_handle);
  });

  testWidgets('tapping the eye control hides the indicator and changes nothing else', (tester) async {
    final original = _config(showCustomSortIndicator: true);
    final received = await openDialog(tester, config: original);

    expect(indicatorToggle(), findsOneWidget);
    expect(badgeIcon(tester), Icons.visibility, reason: 'a visible indicator must show the open eye');

    await tester.tap(indicatorToggle());
    await tester.pumpAndSettle();

    expect(received, hasLength(1), reason: 'the toggle must emit exactly one config');
    final updated = received.single;

    expect(updated.showCustomSortIndicator, isFalse);
    // Every other field must survive untouched — in particular custom sort
    // must stay ON, since hiding the indicator is not disabling reordering.
    expect(updated.useCustomOrder, isTrue);
    expect(updated.enableGrouping, isTrue);
    expect(updated.groupOption?.field, TaskSortFields.status);
    expect(updated.orderOptions.single.field, TaskSortFields.priority);
    expect(updated.orderOptions.single.direction, SortDirection.desc);
    expect(updated.customTagSortOrder, ['tag-1', 'tag-2']);

    // The source config is immutable: it must not have been mutated in place.
    expect(original.showCustomSortIndicator, isTrue);
    expect(identical(updated, original), isFalse);

    // The badge must now discriminate the hidden state.
    expect(badgeIcon(tester), Icons.visibility_off);
  });

  testWidgets('tapping the eye control again restores the indicator', (tester) async {
    final received = await openDialog(tester, config: _config(showCustomSortIndicator: false));

    expect(badgeIcon(tester), Icons.visibility_off, reason: 'a hidden indicator must show the crossed eye');

    await tester.tap(indicatorToggle());
    await tester.pumpAndSettle();

    expect(received.single.showCustomSortIndicator, isTrue);
    expect(received.single.useCustomOrder, isTrue);
    expect(badgeIcon(tester), Icons.visibility);
  });

  testWidgets('the eye control is absent while custom sort is off', (tester) async {
    await openDialog(
      tester,
      config: _config(showCustomSortIndicator: true).copyWith(useCustomOrder: false),
    );

    expect(indicatorToggle(), findsNothing);
  });
}
