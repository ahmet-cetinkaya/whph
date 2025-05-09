import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/presentation/features/tags/components/tag_card.dart';
import 'package:whph/presentation/features/tags/services/tags_service.dart';
import 'package:whph/presentation/shared/components/load_more_button.dart';
import 'package:whph/presentation/shared/components/icon_overlay.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/shared/utils/filter_change_analyzer.dart';

class TagsList extends StatefulWidget {
  final List<String>? filterByTags;
  final VoidCallback? onTagAdded;
  final void Function(TagListItem tag)? onClickTag;
  final void Function(int count)? onList;
  final bool showArchived;

  const TagsList({
    super.key,
    this.filterByTags,
    this.onTagAdded,
    this.onClickTag,
    this.onList,
    this.showArchived = false,
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
    if (oldWidget.showArchived != widget.showArchived ||
        !FilterChangeAnalyzer.areListsEqual(oldWidget.filterByTags, widget.filterByTags)) {
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

    try {
      final query = GetListTagsQuery(
        pageIndex: pageIndex,
        pageSize: 10,
        filterByTags: widget.filterByTags,
        showArchived: widget.showArchived,
      );

      final result = await _mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);

      if (!mounted) return;
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
    } catch (e) {
      // Error handling without showing loading indicators
    }
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
        message: _translationService.translate(TagTranslationKeys.noTagsFound),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._tags!.items.map((tag) => TagCard(
              tag: tag,
              onOpenDetails: () => widget.onClickTag?.call(tag),
            )),
        if (_tags!.hasNext) LoadMoreButton(onPressed: () => _getTags(pageIndex: _tags!.pageIndex + 1)),
      ],
    );
  }
}
