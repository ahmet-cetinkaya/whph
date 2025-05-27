import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'dart:async';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';

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
  final bool initialShowNoTagsFilter;
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
    this.initialShowNoTagsFilter = false,
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
  bool _needsStateUpdate = false;

  @override
  void initState() {
    _selectedTags = widget.initialSelectedTags.map((e) => e.value).toList();
    _hasExplicitlySelectedNone = widget.showNoneOption &&
        (_selectedTags.isEmpty && (widget.initialShowNoTagsFilter || widget.initialNoneSelected));

    if (_hasExplicitlySelectedNone) {
      _selectedTags.clear();
    }

    _getTags(pageIndex: 0);
    _scrollController.addListener(_scrollListener);
    super.initState();
  }

  @override
  void didUpdateWidget(TagSelectDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_selectedTagsChanged(oldWidget.initialSelectedTags, widget.initialSelectedTags)) {
      _selectedTags = widget.initialSelectedTags.map((e) => e.value).toList();
      _needsStateUpdate = true;
    }

    if (oldWidget.showArchived != widget.showArchived) {
      _tags = null;
      _getTags(pageIndex: 0);
    }

    if (oldWidget.initialShowNoTagsFilter != widget.initialShowNoTagsFilter ||
        oldWidget.initialNoneSelected != widget.initialNoneSelected) {
      _hasExplicitlySelectedNone = widget.showNoneOption &&
          (_selectedTags.isEmpty && (widget.initialShowNoTagsFilter || widget.initialNoneSelected));

      if (_hasExplicitlySelectedNone) {
        _selectedTags.clear();
        // Defer the callback to next frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onTagsSelected(const [], true);
          }
        });
      }
      _needsStateUpdate = true;
    }

    if (_needsStateUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _needsStateUpdate = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  bool _selectedTagsChanged(List<DropdownOption<String>> oldTags, List<DropdownOption<String>> newTags) {
    if (oldTags.length != newTags.length) {
      return true;
    }

    final oldValues = oldTags.map((e) => e.value).toSet();
    final newValues = newTags.map((e) => e.value).toSet();

    return oldValues.union(newValues).length != oldValues.length;
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
      },
    );
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

    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_translationService.translate(TagTranslationKeys.selectTooltip)),
              automaticallyImplyLeading: false,
              actions: [
                if (tempSelectedTags.isNotEmpty || _hasExplicitlySelectedNone)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        tempSelectedTags.clear();
                        _hasExplicitlySelectedNone = false;
                      });
                    },
                    icon: Icon(SharedUiConstants.clearIcon),
                    tooltip: _translationService.translate(TagTranslationKeys.clearAllButton),
                  ),
                TextButton(
                  onPressed: () => _confirmTagSelection(tempSelectedTags),
                  child: Text(_translationService.translate(SharedTranslationKeys.doneButton)),
                ),
                const SizedBox(width: AppTheme.sizeSmall),
              ],
            ),
            body: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  // Search Section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
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
                            value.length == 1 ? const Duration(milliseconds: 100) : const Duration(milliseconds: 300),
                            () {
                          _getTags(pageIndex: 0, search: value);
                        });
                      },
                    ),
                  ),

                  // Tag List Section
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: (_tags?.items.length ?? 0) + (widget.showNoneOption ? 2 : 0) + 1,
                      itemBuilder: (context, index) {
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmTagSelection(List<String> tempSelectedTags) {
    if (mounted) {
      setState(() {
        _selectedTags = List<String>.from(tempSelectedTags);
      });
    }

    final isNoneSelected = _hasExplicitlySelectedNone;

    final selectedOptions = tempSelectedTags.map((id) {
      final tag = _tags!.items.firstWhere((tag) => tag.id == id);
      return DropdownOption(
        label: tag.name,
        value: tag.id,
      );
    }).toList();

    widget.onTagsSelected(selectedOptions, isNoneSelected);

    Future.delayed(const Duration(milliseconds: 1), () {
      if (mounted && context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
        displayWidget = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: uniqueSelectedTagIds.map((id) {
              final tag = _tags!.items.firstWhere((t) => t.id == id);
              return Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                  label: Text(tag.name, style: AppTheme.bodySmall),
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
                ),
              );
            }).toList(),
          ),
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
        displayWidget = IconButton(
          icon: Icon(
            widget.icon,
            color: widget.color,
          ),
          iconSize: widget.iconSize ?? AppTheme.iconSizeSmall,
          onPressed: () => _showTagSelectionModal(context),
          tooltip: displayTooltip,
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
      displayWidget = IconButton(
        icon: Icon(
          widget.icon,
          color: widget.color,
        ),
        iconSize: widget.iconSize ?? AppTheme.iconSizeSmall,
        onPressed: () => _showTagSelectionModal(context),
        tooltip: displayTooltip,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showSelectedInDropdown && _selectedTags.isNotEmpty && _tags != null)
          Flexible(
            child: displayWidget,
          )
        else
          Flexible(
            child: widget.buttonLabel != null
                ? InkWell(
                    onTap: () => _showTagSelectionModal(context),
                    child: Tooltip(
                      message: displayTooltip ?? '',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: displayWidget,
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      widget.icon,
                      color: widget.color ?? Theme.of(context).iconTheme.color,
                    ),
                    iconSize: widget.iconSize ?? AppTheme.iconSizeSmall,
                    onPressed: () => _showTagSelectionModal(context),
                    tooltip: displayTooltip ?? '',
                  ),
          ),
        if (widget.showSelectedInDropdown && _selectedTags.isNotEmpty && _tags != null)
          IconButton(
            icon: Icon(
              widget.icon,
              color: widget.color ?? Colors.white,
            ),
            iconSize: widget.iconSize ?? AppTheme.iconSizeSmall,
            onPressed: () => _showTagSelectionModal(context),
            tooltip: _translationService.translate(TagTranslationKeys.selectTooltip),
          ),
      ],
    );
  }
}
