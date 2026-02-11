import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/application/features/tags/models/tag_sort_fields.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_select_dialog.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/features/tags/pages/tag_details_page.dart';
import 'package:acore/acore.dart' show SortDirection, SortOption;

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
  final Widget? headerAction;
  final ButtonStyle? buttonStyle;

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
    this.headerAction,
    this.buttonStyle,
  });

  @override
  State<TagSelectDropdown> createState() => _TagSelectDropdownState();
}

class _TagSelectDropdownState extends State<TagSelectDropdown> {
  final Mediator _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  GetListTagsQueryResponse? _tags;

  List<String> _selectedTags = [];
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

    // We still need to fetch tags to display selected tags in the button/list
    _getTags(pageIndex: 0);
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

  bool _selectedTagsChanged(List<DropdownOption<String>> oldTags, List<DropdownOption<String>> newTags) {
    if (oldTags.length != newTags.length) {
      return true;
    }

    for (int i = 0; i < oldTags.length; i++) {
      if (oldTags[i].value != newTags[i].value) {
        return true;
      }
    }

    return false;
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

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final String item = _selectedTags.removeAt(oldIndex);
      _selectedTags.insert(newIndex, item);
    });

    // Construct the updated list of DropdownOptions to pass back
    final List<DropdownOption<String>> updatedTags = _selectedTags.map((tagId) {
      // Find tag name
      String label = '';
      if (_tags != null) {
        try {
          final tag = _tags!.items.firstWhere((t) => t.id == tagId);
          label = tag.name;
        } catch (_) {}
      }
      return DropdownOption(label: label, value: tagId);
    }).toList();

    widget.onTagsSelected(updatedTags, _hasExplicitlySelectedNone);
  }

  Future<void> _showTagSelectionModal(BuildContext context) async {
    final result = await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      size: DialogSize.xLarge,
      child: TagSelectDialog(
        initialSelectedTags: _selectedTags,
        excludeTagIds: widget.excludeTagIds,
        isMultiSelect: widget.isMultiSelect,
        showNoneOption: widget.showNoneOption,
        initialNoneSelected: widget.initialNoneSelected,
        initialShowNoTagsFilter: widget.initialShowNoTagsFilter,
        limit: widget.limit,
        showArchived: widget.showArchived,
        headerAction: widget.headerAction,
      ),
    );

    if (result != null && result is Map && mounted) {
      final selectedOptions = result['selectedTags'] as List<DropdownOption<String>>;
      final isNoneSelected = result['isNoneSelected'] as bool;

      setState(() {
        _selectedTags = selectedOptions.map((e) => e.value).toList();
        _hasExplicitlySelectedNone = isNoneSelected;
      });

      widget.onTagsSelected(selectedOptions, isNoneSelected);
    }
  }

  void _navigateToTagDetails(String tagId) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: TagDetailsPage(tagId: tagId),
      size: DialogSize.max,
    );
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
              return tag.name.isNotEmpty ? tag.name : _translationService.translate(SharedTranslationKeys.untitled);
            } catch (e) {
              return null;
            }
          })
          .whereType<String>()
          .toList();

      if (widget.showSelectedInDropdown) {
        displayWidget = SizedBox(
            height: 48,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              onReorder: _onReorder,
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: Colors.transparent,
                  child: child,
                );
              },
              itemCount: uniqueSelectedTagIds.length,
              itemBuilder: (context, index) {
                if (index < 0 || index >= uniqueSelectedTagIds.length) return const SizedBox.shrink();

                final id = uniqueSelectedTagIds[index];
                final tagsResponse = _tags;
                if (tagsResponse == null) return const SizedBox.shrink();

                final tag = tagsResponse.items.firstWhereOrNull((t) => t.id == id);
                if (tag == null) return const SizedBox.shrink();

                return ReorderableDelayedDragStartListener(
                  key: ValueKey(id),
                  index: index,
                  child: Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: GestureDetector(
                        onTap: () => _navigateToTagDetails(tag.id),
                        child: Chip(
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                          backgroundColor: AppTheme.surface3,
                          side: BorderSide.none,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                TagUiConstants.getTagTypeIcon(tag.type),
                                size: AppTheme.iconSizeXSmall,
                                color: TagUiConstants.getTagColor(tag.color),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                  tag.name.isNotEmpty
                                      ? tag.name
                                      : _translationService.translate(SharedTranslationKeys.untitled),
                                  style: AppTheme.labelSmall),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  final currentTags = _tags;
                                  if (currentTags == null) return;

                                  final List<DropdownOption<String>> updatedTags =
                                      uniqueSelectedTagIds.where((tagId) => tagId != id).map((tagId) {
                                    final tagItem = currentTags.items.firstWhereOrNull((t) => t.id == tagId);
                                    return DropdownOption(label: tagItem?.name ?? '', value: tagId);
                                  }).toList();

                                  widget.onTagsSelected(updatedTags, _hasExplicitlySelectedNone);
                                  setState(() {
                                    _selectedTags.removeWhere((tagId) => tagId == id);
                                  });
                                },
                                child: Icon(
                                  Icons.close,
                                  size: AppTheme.iconSizeXSmall,
                                  color: widget.color ?? Theme.of(context).iconTheme.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                );
              },
            ));
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
          style: widget.buttonStyle,
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
        style: widget.buttonStyle,
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
                    style: widget.buttonStyle,
                  ),
          ),
        if (widget.showSelectedInDropdown && _selectedTags.isNotEmpty && _tags != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                widget.icon,
                color: widget.color ?? Theme.of(context).iconTheme.color,
              ),
              iconSize: widget.iconSize ?? AppTheme.iconSizeSmall,
              onPressed: () => _showTagSelectionModal(context),
              tooltip: _translationService.translate(TagTranslationKeys.selectTooltip),
              style: widget.buttonStyle,
            ),
          ),
      ],
    );
  }
}
