import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/shared/utils/error_helper.dart';

class TagSelectDropdown extends StatefulWidget {
  final Mediator mediator = container.resolve<Mediator>();

  final List<Tag> initialSelectedTags;
  final List<String> excludeTagIds;
  final bool isMultiSelect;
  final Function(List<DropdownOption<String>>) onTagsSelected;
  final IconData icon;
  final String? buttonLabel;
  final double? iconSize;
  final Color? color;
  final String? tooltip;
  final bool showLength;
  final int? limit;

  TagSelectDropdown({
    super.key,
    this.initialSelectedTags = const [],
    this.excludeTagIds = const [],
    required this.isMultiSelect,
    this.icon = Icons.label,
    this.buttonLabel,
    this.iconSize,
    this.color,
    this.tooltip,
    required this.onTagsSelected,
    this.showLength = false,
    this.limit,
  });

  @override
  State<TagSelectDropdown> createState() => _TagSelectDropdownState();
}

class _TagSelectDropdownState extends State<TagSelectDropdown> {
  GetListTagsQueryResponse? _tags;

  List<String> _selectedTags = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    _selectedTags = widget.initialSelectedTags.map((e) => e.id).toList();
    _getTags(pageIndex: 0);
    _scrollController.addListener(_scrollListener);
    super.initState();
  }

  Future<void> _getTags({required int pageIndex, String? search}) async {
    try {
      var query = GetListTagsQuery(pageIndex: pageIndex, pageSize: 20, search: search);
      var result = await widget.mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);

      if (mounted) {
        setState(() {
          if (widget.initialSelectedTags.isNotEmpty) {
            result.items
                .removeWhere((tag) => widget.initialSelectedTags.any((existingTag) => existingTag.id == tag.id));
          }

          if (widget.excludeTagIds.isNotEmpty) {
            result.items.removeWhere((tag) => widget.excludeTagIds.contains(tag.id));
          }

          if (_tags == null) {
            _tags = result;
            _tags!.items.insertAll(0, widget.initialSelectedTags.map((tag) => TagListItem(id: tag.id, name: tag.name)));
          } else {
            _tags!.items.addAll(result.items);
            _tags!.pageIndex = result.pageIndex;
          }
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace, message: 'Failed to load tags.');
      }
    }
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
                  // Search bar and clear button row
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        // Search bar
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(labelText: 'Search Tags', fillColor: Colors.transparent),
                            onChanged: (value) {
                              if (!mounted) return;
                              setState(() {
                                _tags = null;
                                _getTags(pageIndex: 0, search: value);
                              });
                            },
                          ),
                        ),

                        // Clear all button
                        if (tempSelectedTags.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                tempSelectedTags.clear();
                              });
                            },
                            icon: Icon(Icons.clear),
                            label: Text('Clear All'),
                          ),
                      ],
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
                            if (!mounted) return;
                            setState(() {
                              if (widget.isMultiSelect) {
                                if (value == true) {
                                  if (widget.limit != null && tempSelectedTags.length >= widget.limit!) {
                                    tempSelectedTags.removeAt(0);
                                  }
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
                            final selectedOptions = tempSelectedTags.map((id) {
                              final tag = _tags!.items.firstWhere((tag) => tag.id == id);
                              return DropdownOption(
                                label: tag.name,
                                value: tag.id,
                              );
                            }).toList();

                            widget.onTagsSelected(selectedOptions);
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

    if (mounted) {
      setState(() {
        _selectedTags = tempSelectedTags;
      });
    }
  }

  void reset() {
    setState(() {
      _selectedTags.clear();
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final int selectedCount = _selectedTags.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.buttonLabel != null
            ? TextButton.icon(
                onPressed: () => _showTagSelectionModal(context),
                icon: Icon(widget.icon, size: widget.iconSize, color: widget.color),
                label: Text(widget.buttonLabel!),
              )
            : IconButton(
                icon: Icon(widget.icon, color: widget.color),
                iconSize: widget.iconSize ?? 24.0,
                tooltip: widget.tooltip,
                onPressed: () => _showTagSelectionModal(context),
              ),
        if (widget.showLength && selectedCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              selectedCount.toString(),
              style: TextStyle(
                color: widget.color ?? Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}
