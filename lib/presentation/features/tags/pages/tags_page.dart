import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tags/components/tag_add_form.dart';
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

  Future<void> _openTagDetails(TagListItem tag) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TagDetailsPage(tagId: tag.id),
      ),
    );
    _refreshTags();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshTags,
          ),
        ],
      ),
      body: Column(
        children: [
          TagForm(
            mediator: widget.mediator,
            onTagAdded: _refreshTags, // Notify to refresh the tag list
          ),
          Expanded(
            child: TagsList(
              key: _tagsListKey, // Assign the key to TagsList
              mediator: widget.mediator,
              onTagAdded: _refreshTags,
              onClickTag: _openTagDetails,
            ),
          ),
        ],
      ),
    );
  }
}
