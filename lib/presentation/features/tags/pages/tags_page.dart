import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/components/secondary_app_bar.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_add_button.dart';
import 'package:whph/presentation/features/tags/components/tags_list.dart';
import 'package:whph/presentation/features/tags/pages/tag_details_page.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';

class TagsPage extends StatefulWidget {
  static const String route = '/tags';

  const TagsPage({super.key});

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  final Mediator _mediator = container.resolve<Mediator>();

  List<String>? _selectedTagIds;
  Key _tagsListKey = UniqueKey();
  Key _addButtonKey = const ValueKey('tagAddButton');
  bool _showArchived = false;

  void _refreshTags() {
    setState(() {
      _selectedTagIds = null;
      _tagsListKey = UniqueKey();
      _addButtonKey = ValueKey(DateTime.now().toString());
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

  void _onFilterTags(List<String> tagIds) {
    setState(() {
      _selectedTagIds = tagIds;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SecondaryAppBar(
        context: context,
        title: const Text('Tags'),
        actions: [
          // Add button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TagAddButton(
              key: _addButtonKey,
              onTagCreated: (tagId) {
                _openTagDetails(tagId);
              },
              buttonColor: AppTheme.primaryColor,
              buttonBackgroundColor: AppTheme.surface2,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: ListView(
          children: [
            // Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Tag select dropdown
                  TagSelectDropdown(
                    isMultiSelect: true,
                    onTagsSelected: _onFilterTags,
                    buttonLabel: (_selectedTagIds?.isEmpty ?? true)
                        ? 'Filter by tags'
                        : '${_selectedTagIds!.length} tags selected',
                  ),

                  // Archive toggle button
                  IconButton(
                    icon: Icon(_showArchived ? Icons.archive : Icons.archive_outlined),
                    tooltip: _showArchived ? 'Hide archived tags' : 'Show archived tags',
                    onPressed: () {
                      setState(() {
                        _showArchived = !_showArchived;
                        _tagsListKey = UniqueKey(); // TagsList'i yeniden yüklemek için key'i güncelle
                      });
                    },
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),

            // List
            TagsList(
              key: _tagsListKey,
              mediator: _mediator,
              onTagAdded: _refreshTags,
              onClickTag: (tag) => _openTagDetails(tag.id),
              filterByTags: _selectedTagIds,
              showArchived: _showArchived,
            ),
          ],
        ),
      ),
    );
  }
}
