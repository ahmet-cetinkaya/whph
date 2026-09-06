import 'package:acore/acore.dart' hide Container;
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' as domain;
import 'package:whph/main.dart' as app_main;
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/presentation/ui/features/tasks/services/abstraction/i_default_task_settings_service.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/error_helper.dart';

class MockTranslationService extends Mock implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs, String? defaultValue}) => key;
}

class MockThemeService extends Mock implements IThemeService {
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

class FakeDefaultTaskSettingsService extends Fake implements IDefaultTaskSettingsService {
  @override
  Future<int?> getDefaultEstimatedTime() async => null;

  @override
  Future<(ReminderTime, int?)> getDefaultPlannedDateReminder() async => (ReminderTime.none, null);
}

class FakeTagRepository extends Fake implements ITagRepository {
  @override
  Future<Tag?> getById(String id, {bool includeDeleted = false}) async => null;
}

class FakeTaskRecurrenceService extends Fake implements ITaskRecurrenceService {}

class FakeLogger extends Fake implements ILogger {
  @override
  void debug(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
  @override
  void info(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
  @override
  void warning(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
  @override
  void error(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
  @override
  void fatal(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
}

class FakeContainer extends Fake implements IContainer {
  final Mediator mediator = Mediator(Pipeline());
  final MockTranslationService translationService = MockTranslationService();
  final MockThemeService themeService = MockThemeService();
  final FakeTagRepository tagRepository = FakeTagRepository();
  final FakeDefaultTaskSettingsService defaultTaskSettingsService = FakeDefaultTaskSettingsService();
  late final TasksService tasksService = TasksService(
    FakeTaskRecurrenceService(),
    mediator,
    FakeLogger(),
  );

  @override
  T resolve<T>([String? name]) {
    if (T == Mediator) return mediator as T;
    if (T == ITranslationService) return translationService as T;
    if (T == IThemeService) return themeService as T;
    if (T == ITagRepository) return tagRepository as T;
    if (T == TasksService) return tasksService as T;
    if (T == IDefaultTaskSettingsService) return defaultTaskSettingsService as T;
    throw UnimplementedError('FakeContainer.resolve($T)');
  }
}

/// Tags the stub handler serves.
///
/// Non-empty on purpose: an empty list makes [TagSelectDropdown]'s selection
/// path unreachable, so any test asserting that a chosen tag survives a
/// minimize/restore cycle would pass vacuously.
const stubTagNames = ['Work', 'Home'];

/// Returns an empty tag page so [TagSelectDropdown] can settle without a database.
class StubGetListTagsQueryHandler implements IRequestHandler<GetListTagsQuery, GetListTagsQueryResponse> {
  @override
  Future<GetListTagsQueryResponse> call(GetListTagsQuery request) async {
    final items = <TagListItem>[
      for (var index = 0; index < stubTagNames.length; index++)
        TagListItem(id: 'tag-$index', name: stubTagNames[index]),
    ];

    return GetListTagsQueryResponse(
      items: items,
      totalItemCount: items.length,
      pageIndex: request.pageIndex,
      pageSize: request.pageSize,
    );
  }
}

/// Wires the fake DI container the dialog resolves its services from.
///
/// Call once per test file from `setUpAll`; the returned container is also
/// installed as the global `app_main.container`.
FakeContainer installFakeContainer() {
  final fakeContainer = FakeContainer();
  app_main.container = fakeContainer;
  ErrorHelper.initialize(fakeContainer.translationService);
  fakeContainer.mediator.registerHandler<GetListTagsQuery, GetListTagsQueryResponse, StubGetListTagsQueryHandler>(
    () => StubGetListTagsQueryHandler(),
  );
  return fakeContainer;
}
