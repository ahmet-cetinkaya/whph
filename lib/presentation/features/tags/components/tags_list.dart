import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/acore/queries/models/sort_option.dart';
import 'package:whph/presentation/features/tags/components/tag_card.dart';
import 'package:whph/presentation/features/tags/services/tags_service.dart';
import 'package:whph/presentation/shared/components/load_more_button.dart';
import 'package:whph/presentation/shared/components/icon_overlay.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/models/sort_config.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/core/acore/utils/collection_utils.dart';

class TagsList extends StatefulWidget {
  final List<String>? filterByTags;
  final VoidCallback? onTagAdded;
  final void Function(TagListItem tag)? onClickTag;
  final void Function(int count)? onList;
  final bool showArchived;
  final SortConfig<TagSortFields>? sortConfig;
  final String? search;

  const TagsList({
    super.key,
    this.filterByTags,
    this.onTagAdded,
    this.onClickTag,
    this.onList,
    this.showArchived = false,
    this.sortConfig,
    this.search,
  });

  @override
  State<TagsList> createState() => TagsListState();
}

class TagsListState extends State<TagsList> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _tagsService = container.resolve<TagsService>();

  GetListTagsQueryResponse? _tags;

  @override
  void initState() {
    super.initState();

    _getTags();
    _setupEventListeners();
  }

  @override
  void dispose() {
    super.dispose();

    _removeEventListeners();
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

  Future<void> refresh() async {
    if (!mounted) return;

    await _getTags(isRefresh: true);
  }

  Future<void> _getTags({
    int pageIndex = 0,
    bool isRefresh = false,
  }) async {
    if (isRefresh) {
      _tags = null;
    }

    await AsyncErrorHandler.execute<GetListTagsQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(TagTranslationKeys.errorLoading),
      operation: () async {
        final query = GetListTagsQuery(
          pageIndex: pageIndex,
          pageSize: 10,
          filterByTags: widget.filterByTags,
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
              totalPageCount: result.totalPageCount,
              pageIndex: result.pageIndex,
              pageSize: result.pageSize,
            );
          }
        });

        widget.onList?.call(_tags!.items.length);
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
      return IconOverlay(
        icon: Icons.label_off,
        message: _translationService.translate(TagTranslationKeys.noTags),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._tags!.items.map((tag) => TagCard(
              tag: tag,
              onOpenDetails: () => widget.onClickTag?.call(tag),
            )),
        if (_tags!.hasNext)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.sizeSmall),
            child: Center(child: LoadMoreButton(onPressed: () => _getTags(pageIndex: _tags!.pageIndex + 1))),
          ),
      ],
    );
  }
}
