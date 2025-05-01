import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/presentation/features/tags/components/tag_card.dart';
import 'package:whph/presentation/shared/components/load_more_button.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';

class TagsList extends StatefulWidget {
  final Mediator mediator;
  final List<String>? filterByTags;
  final VoidCallback onTagAdded;
  final void Function(TagListItem tag) onClickTag;
  final void Function(int count)? onList;
  final bool showArchived;

  const TagsList({
    super.key,
    required this.mediator,
    this.filterByTags,
    required this.onTagAdded,
    required this.onClickTag,
    this.onList,
    this.showArchived = false,
  });

  @override
  State<TagsList> createState() => TagsListState();
}

class TagsListState extends State<TagsList> {
  final _translationService = container.resolve<ITranslationService>();
  GetListTagsQueryResponse? _tags;
  final int _pageSize = 20;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void didUpdateWidget(TagsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showArchived != widget.showArchived || oldWidget.filterByTags != widget.filterByTags) {
      refresh();
    }
  }

  Future<void> refresh() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _tags = null; // Clear existing items before refresh
    });

    try {
      await _getTags(pageIndex: 0);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getTags({int pageIndex = 0}) async {
    final query = GetListTagsQuery(
      pageIndex: pageIndex,
      pageSize: _pageSize,
      filterByTags: widget.filterByTags,
      showArchived: widget.showArchived,
    );

    final result = await widget.mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);

    if (mounted) {
      setState(() {
        if (_tags == null) {
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

      if (widget.onList != null) {
        widget.onList!(_tags!.items.length);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tags == null) {
      return const SizedBox.shrink();
    }

    if (_tags!.items.isEmpty) {
      return Center(
        child: Text(_translationService.translate(TagTranslationKeys.noTagsFound)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._tags!.items.map((tag) {
          return TagCard(
            tag: tag,
            onOpenDetails: () => widget.onClickTag(tag),
          );
        }),
        if (_tags!.hasNext) LoadMoreButton(onPressed: () => _getTags(pageIndex: _tags!.pageIndex + 1)),
      ],
    );
  }
}
