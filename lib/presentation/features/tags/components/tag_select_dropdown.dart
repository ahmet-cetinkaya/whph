import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/components/filter_icon_button.dart';

class TagSelectDropdown extends StatefulWidget {
  final List<DropdownOption<String>> initialSelectedTags;
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
  final bool showSelectedInDropdown;

  const TagSelectDropdown({
    super.key,
    this.initialSelectedTags = const [],
    this.excludeTagIds = const [],
    required this.isMultiSelect,
    this.icon = TagUiConstants.tagIcon,
    this.buttonLabel,
    this.iconSize = AppTheme.iconSizeMedium,
    this.color,
    this.tooltip,
    required this.onTagsSelected,
    this.showLength = false,
    this.limit,
    this.showSelectedInDropdown = false,
  });

  @override
  State<TagSelectDropdown> createState() => _TagSelectDropdownState();
}

class _TagSelectDropdownState extends State<TagSelectDropdown> {
  final Mediator _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  GetListTagsQueryResponse? _tags;

  List<String> _selectedTags = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    _selectedTags = widget.initialSelectedTags.map((e) => e.value).toList();
    _getTags(pageIndex: 0);
    _scrollController.addListener(_scrollListener);
    super.initState();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _getTags({required int pageIndex, String? search}) async {
    try {
      final query = GetListTagsQuery(pageIndex: pageIndex, pageSize: 10, search: search);
      final result = await _mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);

      if (mounted) {
        setState(() {
          if (widget.initialSelectedTags.isNotEmpty) {
            result.items
                .removeWhere((tag) => widget.initialSelectedTags.any((existingTag) => existingTag.value == tag.id));
          }

          if (widget.excludeTagIds.isNotEmpty) {
            result.items.removeWhere((tag) => widget.excludeTagIds.contains(tag.id));
          }

          if (_tags == null) {
            _tags = result;
            _tags!.items
                .insertAll(0, widget.initialSelectedTags.map((tag) => TagListItem(id: tag.value, name: tag.label)));
          } else {
            _tags!.items.addAll(result.items);
            _tags!.pageIndex = result.pageIndex;
          }
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: _translationService.translate(TagTranslationKeys.errorLoading));
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

    // Schedule focus request for the next frame after modal is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });

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
                            focusNode: _searchFocusNode,
                            decoration: InputDecoration(
                              labelText: _translationService.translate(TagTranslationKeys.searchLabel),
                              fillColor: Colors.transparent,
                              labelStyle: AppTheme.bodySmall,
                            ),
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
                          IconButton(
                            onPressed: () => setState(() => tempSelectedTags.clear()),
                            icon: Icon(SharedUiConstants.clearIcon),
                            tooltip: _translationService.translate(TagTranslationKeys.clearAllButton),
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
                        final tag = _tags!.items[index];
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
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
                        ),
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
                          child: Text(_translationService.translate(TagTranslationKeys.doneButton)),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tags wrap - on the left
        if (widget.showSelectedInDropdown && _tags != null)
          Expanded(
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _selectedTags.map((tagId) {
                final tag = _tags!.items.firstWhere((t) => t.id == tagId);
                return Chip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(
                    tag.name,
                    style: AppTheme.bodySmall,
                  ),
                  onDeleted: () {
                    final List<DropdownOption<String>> updatedTags = _selectedTags.where((id) => id != tagId).map((id) {
                      final tag = _tags!.items.firstWhere((t) => t.id == id);
                      return DropdownOption(label: tag.name, value: tag.id);
                    }).toList();
                    widget.onTagsSelected(updatedTags);
                    setState(() {
                      _selectedTags.remove(tagId);
                    });
                  },
                );
              }).toList(),
            ),
          ),

        FilterIconButton(
          icon: widget.icon,
          iconSize: widget.iconSize ?? AppTheme.iconSizeSmall,
          onPressed: () => _showTagSelectionModal(context),
          tooltip: widget.tooltip,
          color: widget.color,
        ),
      ],
    );
  }
}
