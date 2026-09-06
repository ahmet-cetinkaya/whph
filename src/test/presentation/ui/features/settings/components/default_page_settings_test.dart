import 'package:acore/acore.dart' hide Container;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' as domain;
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/settings/components/default_page_settings.dart';
import 'package:whph/presentation/ui/features/tasks/pages/tasks_page.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/error_helper.dart';

void main() {
  late _FakeContainer fakeContainer;

  setUp(() {
    fakeContainer = _FakeContainer();
    app_main.container = fakeContainer;
    ErrorHelper.initialize(fakeContainer.translationService);
    fakeContainer.mediator.registerHandler<GetSettingQuery, GetSettingQueryResponse?, _StubGetSettingHandler>(
      () => _StubGetSettingHandler(fakeContainer),
    );
    fakeContainer.mediator
        .registerHandler<SaveSettingCommand, SaveSettingCommandResponse, _RecordingSaveSettingHandler>(
      () => _RecordingSaveSettingHandler(fakeContainer),
    );
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: DefaultPageSettings())));
    await tester.pumpAndSettle();
  }

  testWidgets('shows Today until another page has been chosen', (WidgetTester tester) async {
    await pumpSettings(tester);

    expect(find.text(SharedTranslationKeys.navToday), findsOneWidget);
  });

  testWidgets('shows the page already stored in settings', (WidgetTester tester) async {
    fakeContainer.storedDefaultPage = TasksPage.route;

    await pumpSettings(tester);

    expect(find.text(SharedTranslationKeys.navTasks), findsOneWidget);
  });

  testWidgets('falls back to Today when the stored page no longer exists', (WidgetTester tester) async {
    fakeContainer.storedDefaultPage = '/a-page-that-was-removed';

    await pumpSettings(tester);

    expect(find.text(SharedTranslationKeys.navToday), findsOneWidget);

    // Reopening must show Today as the checked entry too: without the guard the
    // tile label falls back while the stale route stays selected underneath, so
    // picking Today would appear to do nothing.
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    final todayEntry = tester.widget<ListTile>(
      find.ancestor(of: find.text(SharedTranslationKeys.navToday).last, matching: find.byType(ListTile)),
    );
    expect(todayEntry.selected, isTrue);
  });

  testWidgets('saves the picked page and reflects it on the tile', (WidgetTester tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text(SharedTranslationKeys.navTasks).last);
    await tester.pumpAndSettle();

    expect(fakeContainer.savedSettings[SettingKeys.defaultPage], TasksPage.route);
    expect(find.text(SharedTranslationKeys.navTasks), findsOneWidget);
  });

  testWidgets('offers every section, with Today among them', (WidgetTester tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(find.text(SharedTranslationKeys.navToday), findsWidgets);
    expect(find.text(SharedTranslationKeys.navTasks), findsOneWidget);
    expect(find.text(SharedTranslationKeys.navHabits), findsOneWidget);
    expect(find.text(SharedTranslationKeys.navNotes), findsOneWidget);
    expect(find.text(SharedTranslationKeys.navTags), findsOneWidget);
    expect(find.text(SharedTranslationKeys.navAppUsages), findsOneWidget);
  });
}

class _StubGetSettingHandler implements IRequestHandler<GetSettingQuery, GetSettingQueryResponse?> {
  _StubGetSettingHandler(this.container);

  final _FakeContainer container;

  @override
  Future<GetSettingQueryResponse?> call(GetSettingQuery request) async {
    final value = container.storedDefaultPage;
    if (request.key != SettingKeys.defaultPage || value == null) return null;

    return GetSettingQueryResponse(
      id: 'stored-default-page',
      createdDate: DateTime(2024),
      key: SettingKeys.defaultPage,
      value: value,
      valueType: SettingValueType.string,
    );
  }
}

class _RecordingSaveSettingHandler implements IRequestHandler<SaveSettingCommand, SaveSettingCommandResponse> {
  _RecordingSaveSettingHandler(this.container);

  final _FakeContainer container;

  @override
  Future<SaveSettingCommandResponse> call(SaveSettingCommand request) async {
    container.savedSettings[request.key] = request.value;
    return SaveSettingCommandResponse(id: request.key, createdDate: DateTime(2024));
  }
}

class _MockTranslationService extends Mock implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs, String? defaultValue}) => key;
}

class _MockThemeService extends Mock implements IThemeService {
  @override
  Color get primaryColor => Colors.blue;
  @override
  Color get textColor => Colors.black;
  @override
  Color get secondaryTextColor => Colors.grey;
  @override
  Color get surface1 => Colors.grey.shade100;
  @override
  Color get surface2 => Colors.grey.shade200;
  @override
  Color get surface3 => Colors.grey.shade300;
  @override
  domain.UiDensity get currentUiDensity => domain.UiDensity.normal;
}

class _FakeContainer extends Fake implements IContainer {
  final Mediator mediator = Mediator(Pipeline());
  final _MockTranslationService translationService = _MockTranslationService();
  final _MockThemeService themeService = _MockThemeService();
  final Map<String, String> savedSettings = {};

  String? storedDefaultPage;

  @override
  T resolve<T>([String? name]) {
    if (T == Mediator) return mediator as T;
    if (T == ITranslationService) return translationService as T;
    if (T == IThemeService) return themeService as T;
    throw UnimplementedError('No test double registered for $T');
  }
}
