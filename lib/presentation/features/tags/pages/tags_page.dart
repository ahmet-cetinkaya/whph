import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/components/secondary_app_bar.dart';
import 'package:whph/presentation/features/tags/components/tag_add_button.dart';
import 'package:whph/presentation/features/tags/components/tags_list.dart';
import 'package:whph/presentation/features/tags/pages/tag_details_page.dart';

class TagsPage extends StatefulWidget {
  static const String route = '/tags';

  final Mediator mediator = container.resolve<Mediator>();

  TagsPage({super.key});

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  Key _tagsListKey = UniqueKey();

  void _refreshTags() {
    setState(() {
      _tagsListKey = UniqueKey();
    });
  }

  Future<void> _openTagDetails(String tagId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TagDetailsPage(tagId: tagId),
      ),
    );
    _refreshTags();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SecondaryAppBar(
        context: context,
        title: const Text('Tags'),
        actions: [
          TagAddButton(
            onTagCreated: (tagId) {
              _openTagDetails(tagId);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: TagsList(
              key: _tagsListKey,
              mediator: widget.mediator,
              onTagAdded: _refreshTags,
              onClickTag: (tag) => _openTagDetails(tag.id),
            ),
          ),
        ],
      ),
    );
  }
}
