import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';

class TagSelectDropdown extends StatefulWidget {
  final Mediator mediator = container.resolve<Mediator>();
  final bool isMultiSelect;
  final Function(List<String>) onTagsSelected;

  TagSelectDropdown({
    super.key,
    required this.isMultiSelect,
    required this.onTagsSelected,
  });

  @override
  State<TagSelectDropdown> createState() => _TagSelectDropdownState();
}

class _TagSelectDropdownState extends State<TagSelectDropdown> {
  GetListTagsQueryResponse? _tags;

  List<String> _selectedTags = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _buttonLabel = "Filter by tags";

  @override
  void initState() {
    _getTags(pageIndex: 0);
    _scrollController.addListener(_scrollListener);
    super.initState();
  }

  Future<void> _getTags({required int pageIndex, String? search}) async {
    var query = GetListTagsQuery(pageIndex: pageIndex, pageSize: 20, search: search);
    var result = await widget.mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);

    setState(() {
      if (_tags == null) {
        _tags = result;
      } else {
        _tags!.items.addAll(result.items);
        _tags!.pageIndex = result.pageIndex;
      }
    });
  }

  void _scrollListener() {
    if (_scrollController.position.extentAfter < 500) {
      _getTags(pageIndex: _tags!.pageIndex + 1);
    }
  }

  Future<void> _showTagSelectionModal(BuildContext context) async {
    List<String> tempSelectedTags = _selectedTags;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search Tags',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _tags = null;
                          _getTags(pageIndex: 0, search: value);
                        });
                      },
                    ),
                  ),

                  // Tags list
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _tags?.items.length ?? 0,
                      itemBuilder: (context, index) {
                        var tag = _tags!.items[index];
                        return CheckboxListTile(
                          title: Text(tag.name),
                          value: tempSelectedTags.contains(tag.id),
                          onChanged: (bool? value) {
                            setState(() {
                              if (widget.isMultiSelect) {
                                if (value == true) {
                                  tempSelectedTags.add(tag.id);
                                } else {
                                  tempSelectedTags.remove(tag.id);
                                }
                              } else {
                                tempSelectedTags.clear();
                                if (value == true) {
                                  tempSelectedTags.add(tag.id);
                                }
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),

                  // Buttons
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
                        TextButton(
                          onPressed: () {
                            widget.onTagsSelected(tempSelectedTags);
                            Navigator.pop(context);
                          },
                          child: Text('Done'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    setState(() {
      _buttonLabel = tempSelectedTags.isNotEmpty
          ? tempSelectedTags.length == 1
              ? _tags!.items.firstWhere((element) => element.id == tempSelectedTags.first).name
              : "${tempSelectedTags.length} tags selected"
          : "Filter by tags";

      _selectedTags = tempSelectedTags;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextButton.icon(
        onPressed: () => _showTagSelectionModal(context),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.surface2),
        icon: Icon(Icons.label),
        label: Text(_buttonLabel),
      ),
    );
  }
}
