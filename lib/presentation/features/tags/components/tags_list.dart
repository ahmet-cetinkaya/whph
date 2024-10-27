import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/presentation/features/tags/components/tag_card.dart';
import 'package:whph/presentation/features/shared/components/load_more_button.dart';

class TagsList extends StatefulWidget {
  final Mediator mediator;

  final List<String>? filterByTags;

  final VoidCallback onTagAdded;
  final void Function(TagListItem tag) onClickTag;
  final void Function(int count)? onList;

  const TagsList({
    super.key,
    required this.mediator,
    this.filterByTags,
    required this.onTagAdded,
    required this.onClickTag,
    this.onList,
  });

  @override
  State<TagsList> createState() => _TagsListState();
}

class _TagsListState extends State<TagsList> {
  GetListTagsQueryResponse? _tags;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _getTags();
  }

  Future<void> _getTags({int pageIndex = 0}) async {
    var query = GetListTagsQuery(pageIndex: pageIndex, pageSize: _pageSize, filterByTags: widget.filterByTags);
    var queryResponse = await widget.mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);

    setState(() {
      if (_tags == null) {
        _tags = queryResponse;
      } else {
        _tags!.items.addAll(queryResponse.items);
      }
    });

    if (widget.onList != null) {
      widget.onList!(_tags!.items.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tags == null) {
      return const Center(
        child: CircularProgressIndicator(),
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
