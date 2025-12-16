import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
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
  });

  @override
  State<TagsList> createState() => TagsListState();
}

class TagsListState extends State<TagsList> with PaginationMixin<TagsList> {
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tags == null) {
      // No loading indicator since local DB is fast
      return const SizedBox.shrink();
    }

    if (_tags == null || _tags!.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: IconOverlay(
          icon: Icons.label_off,
          message: _translationService.translate(TagTranslationKeys.noTags),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(_tags!.items.length, (index) {
            final tag = _tags!.items[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < _tags!.items.length - 1 ? AppTheme.size2XSmall : 0,
              ),
              child: TagCard(
                tag: tag,
                onOpenDetails: () => widget.onClickTag?.call(tag),
                isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
              ),
            );
          }),
          if (_tags!.hasNext && widget.paginationMode == PaginationMode.loadMore)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.size2XSmall),
              child: Center(child: LoadMoreButton(onPressed: onLoadMore)),
            ),
          if (_tags!.hasNext && widget.paginationMode == PaginationMode.infinityScroll && isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppTheme.sizeMedium),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
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
