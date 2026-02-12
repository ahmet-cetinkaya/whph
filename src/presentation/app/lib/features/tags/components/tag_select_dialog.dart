import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:application/features/tags/queries/get_list_tags_query.dart';
import 'package:application/features/tags/commands/save_tag_command.dart';
import 'package:application/features/tags/models/tag_sort_fields.dart';
import 'package:whph/main.dart';
import 'package:whph/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/constants/shared_ui_constants.dart';
import 'package:whph/shared/models/dropdown_option.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/utils/async_error_handler.dart';
import 'package:whph/features/tags/constants/tag_ui_constants.dart';
import 'package:acore/acore.dart' show SortDirection, SortOption;

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
          });
        }
      },
    );
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
                  itemCount: (_tags?.items.length ?? 0) +
                      (widget.showNoneOption ? 2 : 0) +
                      (_shouldShowCreateOption ? 1 : 0) +
                      1,
                  itemBuilder: (context, index) {
                    int currentIndex = 0;

                    // 1. None Option Header and Item
                    if (widget.showNoneOption) {
                      if (index == currentIndex) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Text(
                            _translationService.translate(SharedTranslationKeys.specialFiltersLabel),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        );
                      }
                      currentIndex++;
                      if (index == currentIndex) {
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
                      currentIndex++;
                    }

                    // 2. Tags Header
                    if (index == currentIndex) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Text(
                          _translationService.translate(TagTranslationKeys.tagsLabel),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      );
                    }
                    currentIndex++;

                    // 3. Create Tag Option
                    if (_shouldShowCreateOption) {
                      if (index == currentIndex) {
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
                      currentIndex++;
                    }

                    // 4. Tag Items
                    final actualIndex = index - currentIndex;

                    if (_tags == null || actualIndex < 0 || actualIndex >= _tags!.items.length) {
                      return const SizedBox.shrink();
                    }

                    final tag = _tags!.items[actualIndex];
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
          });
        }
        if (mounted) {
          _getTags(pageIndex: 0);
        }
      },
    );
  }
}
