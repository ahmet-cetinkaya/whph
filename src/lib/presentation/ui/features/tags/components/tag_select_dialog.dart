import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/core/application/features/tags/models/tag_sort_fields.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:acore/acore.dart' show SortDirection, SortOption;
import 'package:whph/presentation/ui/shared/components/list_group_header.dart';

class TagSelectDialog extends StatefulWidget {
  final List<String> initialSelectedTags;
  final List<String> excludeTagIds;
  final bool isMultiSelect;
  final bool showNoneOption;
  final bool initialNoneSelected;
  final bool initialShowNoTagsFilter;
  final int? limit;
  final bool showArchived;
  final Widget? headerAction;

  const TagSelectDialog({
    super.key,
    required this.initialSelectedTags,
    this.excludeTagIds = const [],
    required this.isMultiSelect,
    this.showNoneOption = false,
    this.initialNoneSelected = false,
    this.initialShowNoTagsFilter = false,
    this.limit,
    this.showArchived = false,
    this.headerAction,
  });

  @override
  State<TagSelectDialog> createState() => _TagSelectDialogState();
}

class _TagSelectDialogState extends State<TagSelectDialog> {
  final Mediator _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  GetListTagsQueryResponse? _tags;
  late List<String> _tempSelectedTags;
  final List<_TagListItem> _displayList = [];
  final Set<String> _collapsedGroups = {};

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  bool _hasExplicitlySelectedNone = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _tempSelectedTags = List<String>.from(widget.initialSelectedTags);

    _hasExplicitlySelectedNone = widget.showNoneOption &&
        (_tempSelectedTags.isEmpty && (widget.initialShowNoTagsFilter || widget.initialNoneSelected));

    if (_hasExplicitlySelectedNone) {
      _tempSelectedTags.clear();
    }

    _getTags(pageIndex: 0);
    _scrollController.addListener(_scrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchDebounce?.cancel();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _getTags({required int pageIndex, String? search}) async {
    await AsyncErrorHandler.execute<GetListTagsQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(TagTranslationKeys.errorLoading),
      operation: () async {
        final query = GetListTagsQuery(
          pageIndex: pageIndex,
          pageSize: 10,
          search: search,
          showArchived: widget.showArchived,
          enableGrouping: true,
          groupBy: SortOption(
            field: TagSortFields.type,
            direction: SortDirection.asc,
          ),
          sortBy: [
            SortOption(
              field: TagSortFields.name,
              direction: SortDirection.asc,
            ),
          ],
        );
        return await _mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);
      },
      onSuccess: (result) {
        if (mounted) {
          setState(() {
            if (widget.excludeTagIds.isNotEmpty) {
              result.items.removeWhere((tag) => widget.excludeTagIds.contains(tag.id));
            }

            if (_tags == null) {
              _tags = result;
            } else {
              _tags!.items.addAll(result.items);
              _tags!.pageIndex = result.pageIndex;
            }
            _buildDisplayList();
          });
        }
      },
    );
  }

  void _buildDisplayList() {
    _displayList.clear();

    // 1. None Option
    if (widget.showNoneOption) {
      const specialFiltersKey = SharedTranslationKeys.specialFiltersLabel;
      final isCollapsed = _collapsedGroups.contains(specialFiltersKey);

      _displayList.add(_TagListItem.header(
        _translationService.translate(specialFiltersKey),
        id: specialFiltersKey,
        isCollapsed: isCollapsed,
      ));

      if (!isCollapsed) {
        _displayList.add(_TagListItem.noneOption());
      }
    }

    // 2. Create Tag Option
    if (_shouldShowCreateOption) {
      _displayList.add(_TagListItem.createOption());
    }

    // 3. Tags Grouped
    if (_tags != null && _tags!.items.isNotEmpty) {
      String? currentGroup;

      for (var tag in _tags!.items) {
        if (tag.groupName != currentGroup) {
          currentGroup = tag.groupName;
          final groupKey = currentGroup ?? TagTranslationKeys.otherCategory;
          final isCollapsed = _collapsedGroups.contains(groupKey);

          final groupName = tag.isGroupNameTranslatable && currentGroup != null
              ? _translationService.translate(currentGroup)
              : currentGroup ?? _translationService.translate(TagTranslationKeys.otherCategory);

          _displayList.add(_TagListItem.header(
            groupName,
            id: groupKey,
            isCollapsed: isCollapsed,
          ));
        }

        // Add tag only if its group is not collapsed
        final groupKey = currentGroup ?? TagTranslationKeys.otherCategory;
        if (!_collapsedGroups.contains(groupKey)) {
          _displayList.add(_TagListItem.tag(tag));
        }
      }
    }
  }

  void _toggleGroupCollapse(String groupId) {
    setState(() {
      if (_collapsedGroups.contains(groupId)) {
        _collapsedGroups.remove(groupId);
      } else {
        _collapsedGroups.add(groupId);
      }
      _buildDisplayList();
    });
  }

  void _scrollListener() {
    if (_scrollController.position.extentAfter < 500) {
      _getTags(pageIndex: _tags!.pageIndex + 1);
    }
  }

  void _confirmTagSelection() {
    final isNoneSelected = _hasExplicitlySelectedNone;

    final selectedOptions = _tempSelectedTags.map((id) {
      TagListItem? tag;
      if (_tags != null) {
        try {
          tag = _tags!.items.firstWhere((t) => t.id == id);
        } catch (_) {
          tag = null;
        }
      }

      return DropdownOption(
        label: tag?.name ?? '',
        value: id,
      );
    }).toList();

    Navigator.pop(context, {
      'selectedTags': selectedOptions,
      'isNoneSelected': isNoneSelected,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_translationService.translate(TagTranslationKeys.selectTooltip)),
        automaticallyImplyLeading: true,
        actions: [
          if (widget.headerAction != null) widget.headerAction!,
          if (_tempSelectedTags.isNotEmpty || _hasExplicitlySelectedNone)
            IconButton(
              onPressed: () {
                setState(() {
                  _tempSelectedTags.clear();
                  _hasExplicitlySelectedNone = false;
                });
              },
              icon: Icon(SharedUiConstants.clearIcon),
              tooltip: _translationService.translate(TagTranslationKeys.clearAllButton),
            ),
          TextButton(
            onPressed: _confirmTagSelection,
            child: Text(_translationService.translate(SharedTranslationKeys.doneButton)),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              // Search Section
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: _translationService.translate(TagTranslationKeys.searchLabel),
                    fillColor: Colors.transparent,
                    labelStyle: AppTheme.bodySmall,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) {
                    if (!mounted) return;

                    setState(() {
                      _tags = null;
                      _displayList.clear();
                    });

                    if (value.isEmpty) {
                      _getTags(pageIndex: 0);
                      return;
                    }

                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(
                        value.length == 1 ? const Duration(milliseconds: 100) : const Duration(milliseconds: 300), () {
                      if (!mounted || _isDisposed) return;
                      _getTags(pageIndex: 0, search: value);
                    });
                  },
                ),
              ),

              // Tag List Section
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: _displayList.length,
                  itemBuilder: (context, index) {
                    final item = _displayList[index];

                    if (item.isHeader) {
                      return ListGroupHeader(
                        key: ValueKey('header_${item.id}'),
                        title: item.headerText!,
                        shouldTranslate: false,
                        isExpanded: !item.isCollapsed,
                        onTap: () => _toggleGroupCollapse(item.id!),
                      );
                    }

                    if (item.isNoneOption) {
                      return CheckboxListTile(
                        title: Text(
                          _translationService.translate(SharedTranslationKeys.noneOption),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        value: _hasExplicitlySelectedNone,
                        onChanged: (bool? value) {
                          if (!mounted) return;
                          setState(() {
                            if (value == true) {
                              _tempSelectedTags.clear();
                              _hasExplicitlySelectedNone = true;
                            } else {
                              _hasExplicitlySelectedNone = false;
                            }
                          });
                        },
                      );
                    }

                    if (item.isCreateOption) {
                      return ListTile(
                        leading: const Icon(Icons.add, color: AppTheme.successColor),
                        title: Text(
                          _translationService.translate(
                            TagTranslationKeys.createTagButton,
                            namedArgs: {'name': _searchController.text.trim()},
                          ),
                          style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold),
                        ),
                        onTap: _createAndSelectTag,
                      );
                    }

                    if (item.tag != null) {
                      final tag = item.tag!;
                      return CheckboxListTile(
                        title: Row(
                          children: [
                            Icon(
                              TagUiConstants.getTagTypeIcon(tag.type),
                              size: AppTheme.iconSizeSmall,
                              color: TagUiConstants.getTagColor(tag.color),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(tag.name.isNotEmpty
                                  ? tag.name
                                  : _translationService.translate(SharedTranslationKeys.untitled)),
                            ),
                          ],
                        ),
                        value: _tempSelectedTags.contains(tag.id),
                        onChanged: (bool? value) {
                          if (!mounted) return;
                          setState(() {
                            if (value == true && _hasExplicitlySelectedNone) {
                              _hasExplicitlySelectedNone = false;
                            }

                            if (widget.isMultiSelect) {
                              if (value == true) {
                                if (widget.limit != null && _tempSelectedTags.length >= widget.limit!) {
                                  _tempSelectedTags.removeAt(0);
                                }
                                _tempSelectedTags.add(tag.id);
                              } else {
                                _tempSelectedTags.remove(tag.id);
                              }
                            } else {
                              _tempSelectedTags.clear();
                              if (value == true) {
                                _tempSelectedTags.add(tag.id);
                              }
                            }
                          });
                        },
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _shouldShowCreateOption {
    final searchText = _searchController.text.trim();
    if (searchText.isEmpty) return false;

    if (_tags == null) return true;

    // Check if any tag exactly matches the search text
    return !_tags!.items.any((tag) => tag.name.toLowerCase() == searchText.toLowerCase());
  }

  Future<void> _createAndSelectTag() async {
    final searchText = _searchController.text.trim();
    if (searchText.isEmpty) return;

    await AsyncErrorHandler.execute<SaveTagCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(TagTranslationKeys.createTagError),
      operation: () async {
        final command = SaveTagCommand(name: searchText);
        return await _mediator.send<SaveTagCommand, SaveTagCommandResponse>(command);
      },
      onSuccess: (result) {
        if (mounted) {
          setState(() {
            // Clear 'None' option state when creating a tag
            if (_hasExplicitlySelectedNone) {
              _hasExplicitlySelectedNone = false;
            }
            // In single-select mode, clear previous selections
            if (!widget.isMultiSelect) {
              _tempSelectedTags.clear();
            }
            _tempSelectedTags.add(result.id);
            _searchController.clear();
            _tags = null; // Refresh list to include new tag
            _displayList.clear();
          });
        }
        if (mounted) {
          _getTags(pageIndex: 0);
        }
      },
    );
  }
}

class _TagListItem {
  final TagListItem? tag;
  final String? headerText;
  final String? id; // Group ID for headers
  final bool isHeader;
  final bool isNoneOption;
  final bool isCreateOption;
  final bool isCollapsed;

  _TagListItem._({
    this.tag,
    this.headerText,
    this.id,
    this.isHeader = false,
    this.isNoneOption = false,
    this.isCreateOption = false,
    this.isCollapsed = false,
  });

  factory _TagListItem.tag(TagListItem tag) {
    return _TagListItem._(tag: tag);
  }

  factory _TagListItem.header(String text, {required String id, bool isCollapsed = false}) {
    return _TagListItem._(headerText: text, id: id, isHeader: true, isCollapsed: isCollapsed);
  }

  factory _TagListItem.noneOption() {
    return _TagListItem._(isNoneOption: true);
  }

  factory _TagListItem.createOption() {
    return _TagListItem._(isCreateOption: true);
  }
}
