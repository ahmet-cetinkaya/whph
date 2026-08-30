import 'package:acore/acore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class _FakeContainer extends Fake implements IContainer {
  final Map<Type, dynamic> _services = {};

  void register<T>(T service) {
    _services[T] = service;
  }

  @override
  T resolve<T>() {
    final service = _services[T];
    if (service == null) {
      throw Exception('Service of type $T not registered in mock container');
    }
    return service as T;
  }
}

class _FakeMediator extends Fake implements Mediator {
  final GetListTagsQueryResponse response;

  _FakeMediator(this.response);

  @override
  Future<TResponse> send<TRequest extends IRequest<TResponse>, TResponse>(TRequest request) async =>
      response as TResponse;
}

class _FakeTranslationService extends Fake implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
}

void main() {
  testWidgets('renders selected tags that are not present on the first query page', (tester) async {
    final selectedTagIds = ['tag-1', 'tag-2', 'tag-3'];
    final initialSelectedTags = selectedTagIds.map((id) => DropdownOption(label: 'Tag $id', value: id)).toList();
    final response = GetListTagsQueryResponse(
      items: [
        TagListItem(
          id: 'tag-1',
          name: 'Tag tag-1',
          type: TagType.label,
        ),
      ],
      totalItemCount: 3,
      pageIndex: 0,
      pageSize: 10,
    );
    final fakeContainer = _FakeContainer()
      ..register<Mediator>(_FakeMediator(response))
      ..register<ITranslationService>(_FakeTranslationService());
    container = fakeContainer;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TagSelectDropdown(
            initialSelectedTags: initialSelectedTags,
            onTagsSelected: (tags, isNoneSelected) {},
            showSelectedInDropdown: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.byType(Chip), findsNWidgets(3));
    expect(
      tester.widget<ReorderableListView>(find.byType(ReorderableListView)).scrollDirection,
      Axis.horizontal,
    );
  });
}
