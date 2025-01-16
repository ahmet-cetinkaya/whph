import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/components/app_logo.dart';
import 'package:whph/presentation/features/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_add_button.dart';
import 'package:whph/presentation/features/tags/components/tags_list.dart';
import 'package:whph/presentation/features/tags/pages/tag_details_page.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/shared/constants/navigation_items.dart';

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
    await Navigator.of(context).pushNamed(
      TagDetailsPage.route,
      arguments: {'id': tagId},
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
    return ResponsiveScaffoldLayout(
      appBarTitle: Row(
        children: [
          const AppLogo(width: 32, height: 32),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: const Text('Tags'),
          )
        ],
      ),
      appBarActions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TagAddButton(
            key: _addButtonKey,
            onTagCreated: (tagId) {
              _openTagDetails(tagId);
            },
            buttonColor: AppTheme.primaryColor,
          ),
        ),
      ],
      topNavItems: NavigationItems.topNavItems,
      bottomNavItems: NavigationItems.bottomNavItems,
      routes: {},
      defaultRoute: (context) => Padding(
        padding: const EdgeInsets.all(8),
        child: ListView(
          children: [
            // Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Tag filter
                  TagSelectDropdown(
                    isMultiSelect: true,
                    onTagsSelected: _onFilterTags,
                    icon: Icons.label_outline,
                    iconSize: 20,
                    color: _selectedTagIds?.isNotEmpty ?? false ? AppTheme.primaryColor : Colors.grey,
                    tooltip: 'Filter by tags',
                    showLength: true,
                  ),

                  // Show archived tags
                  FilterIconButton(
                    icon: _showArchived ? Icons.archive : Icons.archive_outlined,
                    color: _showArchived ? AppTheme.primaryColor : null,
                    tooltip: _showArchived ? 'Hide archived tags' : 'Show archived tags',
                    onPressed: () {
                      setState(() {
                        _showArchived = !_showArchived;
                        _tagsListKey = UniqueKey();
                      });
                    },
                  )
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
