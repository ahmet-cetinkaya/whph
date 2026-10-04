import 'package:acore/acore.dart' hide Container;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tag_tags_query.dart';
import 'package:whph/core/application/features/tags/queries/get_tag_query.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/tags/components/tag_details_content.dart';
import 'package:whph/presentation/ui/features/tags/services/tags_service.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class _FakeTranslationService extends Fake implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
}

class _FakeMediator extends Fake implements Mediator {
  TagType type = TagType.label;
  bool failSave = false;
  final List<SaveTagCommand> saves = [];

  @override
  Future<R> send<T extends IRequest<R>, R extends Object?>(T request) async {
    final Object message = request;
    if (message is GetTagQuery) {
      return GetTagQueryResponse(
        id: message.id,
        createdDate: DateTime.utc(2026, 1, 1),
        name: 'Tag',
        type: type,
      ) as R;
    }
    if (message is GetListTagTagsQuery) {
      return GetListTagTagsQueryResponse(items: [], totalItemCount: 0, pageIndex: 0, pageSize: message.pageSize) as R;
    }
    if (message is SaveTagCommand) {
      saves.add(message);
      if (failSave) throw Exception('save failed');
      return SaveTagCommandResponse(id: message.id!, createdDate: DateTime.utc(2026, 1, 1)) as R;
    }
    throw UnsupportedError('Unexpected request: $request');
  }
}

class _FakeContainer extends Fake implements IContainer {
  final Map<Type, Object> _registrations = {};

  void register<T extends Object>(T instance) => _registrations[T] = instance;

  @override
  T resolve<T>([String? name]) {
    final registration = _registrations[T];
    if (registration == null) throw StateError('Service not registered: $T');
    return registration as T;
  }
}

void main() {
  const withinWindow = Duration(milliseconds: 50);

  late _FakeContainer container;
  late _FakeMediator mediator;

  setUpAll(() {
    container = _FakeContainer();
    app_main.container = container;
  });

  setUp(() {
    mediator = _FakeMediator();
    container.register<Mediator>(mediator);
    container.register<TagsService>(TagsService());
    container.register<ITranslationService>(_FakeTranslationService());
  });

  Future<void> pumpEditor(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TagDetailsContent(tagId: 't1'))));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pumpAndSettle();
  }

  testWidgets('(a) leaving within the debounce still saves the typed name once', (tester) async {
    await pumpEditor(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Typed just before leaving');
    await tester.pump(withinWindow);
    expect(mediator.saves, isEmpty);

    await unmount(tester);

    expect(mediator.saves, hasLength(1));
    expect(mediator.saves.single.name, 'Typed just before leaving');
    expect(mediator.saves.single.id, 't1');
  });

  testWidgets('(b) leaving within the debounce after a type change still saves the type', (tester) async {
    // The colour pick itself is not tested: ColorField opens a dialog-based picker that is impractical to drive
    // here. The type dropdown goes through the same _saveTag path, so it covers the non-text edit.
    mediator.type = TagType.context;
    await pumpEditor(tester);
    await tester.tap(find.byType(DropdownButtonFormField<TagType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Project').last);
    await tester.pump(withinWindow);
    expect(mediator.saves, isEmpty);

    await unmount(tester);

    expect(mediator.saves, hasLength(1));
    expect(mediator.saves.single.type, TagType.project);
  });

  testWidgets('(c) leaving with nothing pending sends nothing', (tester) async {
    await pumpEditor(tester);
    await unmount(tester);

    expect(mediator.saves, isEmpty);
  });

  testWidgets('(d) a failing save during the flush does not throw', (tester) async {
    await pumpEditor(tester);
    mediator.failSave = true;
    await tester.enterText(find.byType(TextFormField).first, 'X');
    await tester.pump(withinWindow);

    await unmount(tester);

    expect(tester.takeException(), isNull);
    expect(mediator.saves, hasLength(1));
  });

  testWidgets('(e) typing and waiting past the debounce saves exactly once, leaving adds nothing', (tester) async {
    await pumpEditor(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Typed');
    await tester.pump(SharedUiConstants.contentSaveDebounceTime + withinWindow);
    await tester.pumpAndSettle();
    expect(mediator.saves, hasLength(1));

    await unmount(tester);

    expect(mediator.saves, hasLength(1));
  });
}
