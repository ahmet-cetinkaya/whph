import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
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
        displayWidget = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: uniqueSelectedTagIds.map((id) {
              final tag = _tags!.items.firstWhere((t) => t.id == id);
              return Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: GestureDetector(
                  onTap: () => _navigateToTagDetails(tag.id),
                  child: Chip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                      backgroundColor: AppTheme.surface3,
                      side: BorderSide.none,
                      label: Text(
                          tag.name.isNotEmpty
                              ? tag.name
                              : _translationService.translate(SharedTranslationKeys.untitled),
                          style: AppTheme.labelSmall),
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
                      deleteIcon: Icon(
                        Icons.close,
                        size: AppTheme.iconSizeXSmall,
                        color: widget.color ?? Theme.of(context).iconTheme.color,
                      ),
                      deleteButtonTooltipMessage: _translationService.translate(TagTranslationKeys.removeTagTooltip)),
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
