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
import 'dart:async';

class TagSelectDropdown extends StatefulWidget {
  final List<DropdownOption<String>> initialSelectedTags;
  final List<String> excludeTagIds;
  final bool isMultiSelect;
  final IconData icon;
  final String? buttonLabel;
  final double? iconSize;
  final Color? color;
  final String? tooltip;
  final bool showLength;
  final int? limit;
  final bool showSelectedInDropdown;
  final bool showArchived;
  final bool showNoneOption;
  final bool initialNoneSelected;
  final Function(List<DropdownOption<String>>, bool isNoneSelected) onTagsSelected;

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
    this.showArchived = false,
    this.showNoneOption = false,
    this.initialNoneSelected = false,
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
  Timer? _searchDebounce;
  bool _hasExplicitlySelectedNone = false;

  @override
  void initState() {
    _selectedTags = widget.initialSelectedTags.map((e) => e.value).toList();
    // Initialize the None selection state
    _hasExplicitlySelectedNone = widget.showNoneOption && _selectedTags.isEmpty && widget.initialNoneSelected;
    _getTags(pageIndex: 0);
    _scrollController.addListener(_scrollListener);
    super.initState();
  }

  @override
  void didUpdateWidget(TagSelectDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle changes to showArchived
    if (oldWidget.showArchived != widget.showArchived) {
      // Clear non-matching tags when switching archived mode by refreshing the list
      _tags = null;
      _getTags(pageIndex: 0);
    }

    // Handle changes to initialNoneSelected
    if (oldWidget.initialNoneSelected != widget.initialNoneSelected) {
      if (widget.initialNoneSelected) {
        setState(() {
          // Update None selection state when it changes externally
          _hasExplicitlySelectedNone = widget.initialNoneSelected;
          // Clear tag selections when None is selected
          if (_hasExplicitlySelectedNone) {
            _selectedTags.clear();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _getTags({required int pageIndex, String? search}) async {
    try {
      final query = GetListTagsQuery(
        pageIndex: pageIndex,
        pageSize: 10,
        search: search,
        showArchived: widget.showArchived,
      );
      final result = await _mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);

      if (mounted) {
        setState(() {
          if (widget.excludeTagIds.isNotEmpty) {
            result.items.removeWhere((tag) => widget.excludeTagIds.contains(tag.id));
          }

          if (_tags == null) {
            _tags = result;
            // Only include valid initial tags that match the current archive state
            _selectedTags = widget.initialSelectedTags
                .where((tag) => result.items.any((t) => t.id == tag.value))
                .map((e) => e.value)
                .toList();
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
    List<String> tempSelectedTags = List<String>.from(_selectedTags);
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
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
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
                              });

                              if (value.isEmpty) {
                                _getTags(pageIndex: 0);
                                return;
                              }

                              _searchDebounce?.cancel();
                              _searchDebounce = Timer(
                                  value.length == 1
                                      ? const Duration(milliseconds: 100)
                                      : const Duration(milliseconds: 300), () {
                                _getTags(pageIndex: 0, search: value);
                              });
                            },
                          ),
                        ),
                        if (tempSelectedTags.isNotEmpty || _hasExplicitlySelectedNone)
                          IconButton(
                            onPressed: () {
                              setState(() {
                                // Clear tag selections AND reset None selection state
                                tempSelectedTags.clear();
                                _hasExplicitlySelectedNone = false;
                              });
                            },
                            icon: Icon(SharedUiConstants.clearIcon),
                            tooltip: _translationService.translate(TagTranslationKeys.clearAllButton),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      controller: _scrollController,
                      // Adjust itemCount for headers
                      itemCount: (_tags?.items.length ?? 0) +
                          (widget.showNoneOption ? 2 : 0) + // +1 for None option, +1 for header
                          1, // Tags header
                      itemBuilder: (context, index) {
                        // Show "Special Filters" header
                        if (widget.showNoneOption && index == 0) {
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

                        // Show "None" option
                        if (widget.showNoneOption && index == 1) {
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
                                  tempSelectedTags.clear();
                                  _hasExplicitlySelectedNone = true;
                                } else {
                                  _hasExplicitlySelectedNone = false;
                                }
                              });
                            },
                          );
                        }

                        // Show "Tags" header
                        if (widget.showNoneOption ? index == 2 : index == 0) {
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

                        // Calculate actual index for tag items
                        final actualIndex = widget.showNoneOption ? index - 3 : index - 1;

                        if (_tags == null || actualIndex < 0 || actualIndex >= _tags!.items.length) {
                          return const SizedBox.shrink();
                        }

                        final tag = _tags!.items[actualIndex];
                        return CheckboxListTile(
                          title: Text(tag.name),
                          value: tempSelectedTags.contains(tag.id),
                          onChanged: (bool? value) {
                            if (!mounted) return;
                            setState(() {
                              if (value == true && _hasExplicitlySelectedNone) {
                                _hasExplicitlySelectedNone = false;
                              }

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
                            if (mounted) {
                              setState(() {
                                _selectedTags = List<String>.from(tempSelectedTags);
                                // Also update the explicit None selection state
                              });
                            }

                            // Get None selection state for callback
                            final isNoneSelected = _hasExplicitlySelectedNone;

                            final selectedOptions = tempSelectedTags.map((id) {
                              final tag = _tags!.items.firstWhere((tag) => tag.id == id);
                              return DropdownOption(
                                label: tag.name,
                                value: tag.id,
                              );
                            }).toList();

                            // Pass the selections to the parent with None state
                            widget.onTagsSelected(selectedOptions, isNoneSelected);

                            Future.delayed(const Duration(milliseconds: 1), () {
                              if (context.mounted && Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            });
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
  }

  void reset() {
    setState(() {
      _selectedTags.clear();
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Initialize display variables
    Widget displayWidget;
    String? displayTooltip = widget.tooltip;

    if (_hasExplicitlySelectedNone) {
      displayWidget = Text(
        _translationService.translate(SharedTranslationKeys.noneOption),
        style: AppTheme.bodySmall.copyWith(
          color: widget.color ?? Theme.of(context).iconTheme.color,
        ),
      );
      displayTooltip = _translationService.translate(SharedTranslationKeys.noneOption);
    } else if (_selectedTags.isNotEmpty && _tags != null) {
      // Tekrarlı tagId'leri önlemek için benzersizleştir
      final uniqueSelectedTagIds = _selectedTags.toSet().toList();
      final selectedTagNames = uniqueSelectedTagIds
          .map((id) {
            try {
              final tag = _tags!.items.firstWhere((t) => t.id == id);
              return tag.name;
            } catch (e) {
              return null;
            }
          })
          .whereType<String>()
          .toList();

      if (widget.showSelectedInDropdown) {
        displayWidget = Wrap(
          spacing: 4.0,
          runSpacing: 4.0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...uniqueSelectedTagIds.map((id) {
              final tag = _tags!.items.firstWhere((t) => t.id == id);
              return Chip(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                label: Text(
                  tag.name,
                  style: AppTheme.bodySmall,
                ),
                onDeleted: () {
                  final List<DropdownOption<String>> updatedTags =
                      uniqueSelectedTagIds.where((tagId) => tagId != id).map((tagId) {
                    final tagItem = _tags!.items.firstWhere((t) => t.id == tagId);
                    return DropdownOption(label: tagItem.name, value: tagItem.id);
                  }).toList();
                  widget.onTagsSelected(updatedTags, _hasExplicitlySelectedNone);
                  setState(() {
                    _selectedTags.removeWhere((tagId) => tagId == id);
                  });
                },
              );
            }),
            IconButton(
              icon: Icon(
                widget.icon,
                size: widget.iconSize ?? AppTheme.iconSizeSmall,
                color: widget.color ?? Theme.of(context).iconTheme.color,
              ),
              onPressed: () => _showTagSelectionModal(context),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: _translationService.translate(TagTranslationKeys.selectTooltip),
            ),
          ],
        );
      } else if (widget.buttonLabel != null) {
        displayWidget = Text(
          widget.buttonLabel!,
          style: AppTheme.bodySmall.copyWith(
            color: widget.color ?? Theme.of(context).iconTheme.color,
          ),
        );
        if (selectedTagNames.isNotEmpty) {
          displayTooltip = selectedTagNames.join(', ');
        }
      } else {
        displayWidget = Icon(
          widget.icon,
          size: widget.iconSize ?? AppTheme.iconSizeSmall,
          color: widget.color,
        );
        if (selectedTagNames.isNotEmpty) {
          displayTooltip = selectedTagNames.join(', ');
        }
      }
    } else if (widget.buttonLabel != null) {
      displayWidget = Text(
        widget.buttonLabel!,
        style: AppTheme.bodySmall.copyWith(
          color: widget.color ?? Theme.of(context).iconTheme.color,
        ),
      );
    } else {
      displayWidget = Icon(
        widget.icon,
        size: widget.iconSize ?? AppTheme.iconSizeSmall,
        color: widget.color,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showSelectedInDropdown && _selectedTags.isNotEmpty && _tags != null)
          displayWidget
        else
          Flexible(
            child: InkWell(
              onTap: () => _showTagSelectionModal(context),
              child: Tooltip(
                message: displayTooltip ?? '',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: displayWidget,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
