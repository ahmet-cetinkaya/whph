import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/application/features/tags/models/tag_sort_fields.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_card.dart';
import 'package:whph/presentation/ui/features/tags/services/tags_service.dart';
import 'package:whph/presentation/ui/shared/components/load_more_button.dart';
import 'package:whph/presentation/ui/shared/components/icon_overlay.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/enums/pagination_mode.dart';
import 'package:whph/presentation/ui/shared/mixins/pagination_mixin.dart';

import 'package:whph/presentation/ui/shared/components/list_group_header.dart';
import 'package:whph/presentation/ui/shared/mixins/list_group_collapse_mixin.dart';

class TagsList extends StatefulWidget implements IPaginatedWidget {
  final List<String>? filterByTags;
  final VoidCallback? onTagAdded;
  final void Function(TagListItem tag)? onClickTag;
  final void Function(int count)? onList;
  final bool showArchived;
  final SortConfig<TagSortFields>? sortConfig;
  final String? search;
  final int pageSize;
  @override
  final PaginationMode paginationMode;

  final Widget? header;

  const TagsList({
    super.key,
    this.filterByTags,
    this.onTagAdded,
    this.onClickTag,
    this.onList,
    this.showArchived = false,
    this.sortConfig,
    this.search,
    this.pageSize = 10,
    this.paginationMode = PaginationMode.loadMore,
    this.header,
  });

  @override
  State<TagsList> createState() => TagsListState();
}

class TagsListState extends State<TagsList> with PaginationMixin<TagsList>, ListGroupCollapseMixin<TagsList> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _tagsService = container.resolve<TagsService>();
  final ScrollController _scrollController = ScrollController();

  GetListTagsQueryResponse? _tags;
  double? _savedScrollPosition;

  @override
  ScrollController get scrollController => _scrollController;

  @override
  bool get hasNextPage => _tags?.hasNext ?? false;

  @override
  void initState() {
    super.initState();

    _getTags();
    _setupEventListeners();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _removeEventListeners();
    super.dispose();
  }

  @override
  void didUpdateWidget(TagsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool sortConfigChanged =
        (oldWidget.sortConfig?.orderOptions.length ?? 0) != (widget.sortConfig?.orderOptions.length ?? 0);

    if (oldWidget.sortConfig != null && widget.sortConfig != null && !sortConfigChanged) {
      if (oldWidget.sortConfig!.groupOption != widget.sortConfig!.groupOption ||
          oldWidget.sortConfig!.enableGrouping != widget.sortConfig!.enableGrouping) {
        sortConfigChanged = true;
      } else {
        // Check if any sort option has changed
        for (int i = 0; i < oldWidget.sortConfig!.orderOptions.length; i++) {
          final oldOption = oldWidget.sortConfig!.orderOptions[i];
          final newOption = widget.sortConfig!.orderOptions[i];
          if (oldOption.field != newOption.field || oldOption.direction != newOption.direction) {
            sortConfigChanged = true;
            break;
          }
        }
      }
    }

    if (oldWidget.showArchived != widget.showArchived ||
        !CollectionUtils.areListsEqual(oldWidget.filterByTags, widget.filterByTags) ||
        oldWidget.search != widget.search ||
        sortConfigChanged) {
      refresh();
    }
  }

  void _setupEventListeners() {
    _tagsService.onTagCreated.addListener(_onTagUpdated);
    _tagsService.onTagUpdated.addListener(_onTagUpdated);
    _tagsService.onTagDeleted.addListener(_onTagUpdated);
  }

  void _removeEventListeners() {
    _tagsService.onTagCreated.removeListener(_onTagUpdated);
    _tagsService.onTagUpdated.removeListener(_onTagUpdated);
    _tagsService.onTagDeleted.removeListener(_onTagUpdated);
  }

  void _onTagUpdated() {
    if (!mounted) return;

    _getTags(isRefresh: true);
  }

  void _saveScrollPosition() {
    if (_scrollController.hasClients && _scrollController.position.hasViewportDimension) {
      _savedScrollPosition = _scrollController.position.pixels;
    }
  }

  void _backLastScrollPosition() {
    if (_savedScrollPosition == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _scrollController.hasClients &&
          _scrollController.position.hasViewportDimension &&
          _savedScrollPosition! <= _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(_savedScrollPosition!);
      }
    });
  }

  Future<void> refresh() async {
    if (!mounted) return;

    _saveScrollPosition();
    await _getTags(isRefresh: true);
    _backLastScrollPosition();
  }

  Future<void> _getTags({int pageIndex = 0, bool isRefresh = false}) async {
    if (isRefresh) {
      _tags = null;
    }

    await AsyncErrorHandler.execute<GetListTagsQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(TagTranslationKeys.errorLoading),
      operation: () async {
        final query = GetListTagsQuery(
          pageIndex: pageIndex,
          pageSize: isRefresh && (_tags?.items.length ?? 0) > widget.pageSize
              ? _tags?.items.length ?? widget.pageSize
              : widget.pageSize,
          showArchived: widget.showArchived,
          search: widget.search,
          sortBy: widget.sortConfig?.orderOptions
              .map((option) => SortOption(field: option.field, direction: option.direction))
              .toList(),
          groupBy: widget.sortConfig?.groupOption,
          enableGrouping: widget.sortConfig?.enableGrouping ?? false,
        );

        return await _mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);
      },
      onSuccess: (result) {
        setState(() {
          if (_tags == null || isRefresh) {
            _tags = result;
          } else {
            _tags = GetListTagsQueryResponse(
              items: [..._tags!.items, ...result.items],
              totalItemCount: result.totalItemCount,
              pageIndex: result.pageIndex,
              pageSize: result.pageSize,
            );
          }
        });

        widget.onList?.call(_tags!.items.length);

        // For infinity scroll: check if viewport needs more content
        if (widget.paginationMode == PaginationMode.infinityScroll && _tags!.hasNext) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            checkAndFillViewport();
          });
        }
      },
      onError: (_) {
        // Notify parent that list is loaded (even if empty/error) to dismiss loading overlay
        widget.onList?.call(0);
      },
    );
  }

  List<Widget> _buildTagItems() {
    final List<Widget> listItems = [];
    if (_tags == null || _tags!.items.isEmpty) return listItems;

    String? currentGroup;
    final sortConfig = widget.sortConfig;
    final showHeaders = ((sortConfig?.orderOptions.isNotEmpty ?? false) || (sortConfig?.groupOption != null)) &&
        (sortConfig?.enableGrouping ?? false);

    for (var i = 0; i < _tags!.items.length; i++) {
      final tag = _tags!.items[i];

      if (showHeaders && tag.groupName != null && tag.groupName != currentGroup) {
        currentGroup = tag.groupName;
        if (i > 0) {
          listItems.add(SizedBox(
            key: ValueKey('separator_header_${tag.id}'),
            height: AppTheme.sizeSmall,
          ));
        }
        listItems.add(ListGroupHeader(
          key: ValueKey('header_${tag.groupName}_$i'),
          title: tag.groupName!,
          shouldTranslate: tag.isGroupNameTranslatable,
          isExpanded: !collapsedGroups.contains(tag.groupName),
          onTap: () => toggleGroupCollapse(tag.groupName!),
        ));
      } else if (showHeaders && currentGroup != null && collapsedGroups.contains(currentGroup)) {
        // Skip separator if group is collapsed
      } else if (i > 0) {
        listItems.add(SizedBox(
          key: ValueKey('separator_item_${tag.id}'),
          height: AppTheme.sizeSmall, // Consistent gap
        ));
      }

      if (showHeaders && currentGroup != null && collapsedGroups.contains(currentGroup)) {
        continue;
      }

      listItems.add(Padding(
        key: ValueKey('tag_${tag.id}'),
        padding: EdgeInsets.zero,
        child: TagCard(
          tag: tag,
          onOpenDetails: () => widget.onClickTag?.call(tag),
          isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
        ),
      ));
    }
    return listItems;
  }

  @override
  Widget build(BuildContext context) {
    if (_tags == null) {
      if (widget.header != null) {
        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
          children: [widget.header!],
        );
      }
      return const SizedBox.shrink();
    }

    if (_tags!.items.isEmpty) {
      return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
        children: [
          if (widget.header != null) widget.header!,
          Padding(
            padding: const EdgeInsets.all(AppTheme.sizeMedium),
            child: IconOverlay(
              icon: Icons.label_off,
              message: _translationService.translate(TagTranslationKeys.noTags),
            ),
          ),
        ],
      );
    }

    final listItems = _buildTagItems();
    final showLoadMore = _tags!.hasNext && widget.paginationMode == PaginationMode.loadMore;
    final showInfinityLoading =
        _tags!.hasNext && widget.paginationMode == PaginationMode.infinityScroll && isLoadingMore;
    final extraItemCount = (showLoadMore || showInfinityLoading) ? 1 : 0;
    final headerCount = widget.header != null ? 1 : 0;

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
      itemCount: headerCount + listItems.length + extraItemCount,
      itemBuilder: (context, index) {
        if (widget.header != null) {
          if (index == 0) return widget.header!;
          index--;
        }

        if (index < listItems.length) {
          return listItems[index];
        } else if (showLoadMore) {
          return Padding(
            key: const ValueKey('load_more_button'),
            padding: const EdgeInsets.only(top: AppTheme.size2XSmall),
            child: Center(child: LoadMoreButton(onPressed: onLoadMore)),
          );
        } else if (showInfinityLoading) {
          return const Padding(
            key: ValueKey('infinity_loading_indicator'),
            padding: EdgeInsets.symmetric(vertical: AppTheme.sizeMedium),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Future<void> onLoadMore() async {
    if (_tags == null || !_tags!.hasNext) return;

    _saveScrollPosition();
    await _getTags(pageIndex: _tags!.pageIndex + 1);
    _backLastScrollPosition();
  }
}
