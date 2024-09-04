import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/presentation/features/tags/components/tag_card.dart';

class TagsList extends StatefulWidget {
  final Mediator mediator;
  final VoidCallback onTagAdded;
  final void Function(TagListItem tag) onClickTag;

  const TagsList({
    super.key,
    required this.mediator,
    required this.onTagAdded,
    required this.onClickTag,
  });

  @override
  State<TagsList> createState() => _TagsListState();
}

class _TagsListState extends State<TagsList> {
  List<TagListItem> _tags = [];
  int _pageIndex = 0;
  bool _hasNext = false;
  final ScrollController _scrollController = ScrollController();
  int _loadingCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchTags();
    _setupScrollListener();
  }

  Future<void> _fetchTags({int pageIndex = 0}) async {
    setState(() {
      _loadingCount++;
    });

    var query = GetListTagsQuery(pageIndex: pageIndex, pageSize: 100); //TODO: Add lazy loading
    var queryResponse = await widget.mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);

    setState(() {
      _tags = [..._tags, ...queryResponse.items];
      _pageIndex = pageIndex;
      _hasNext = queryResponse.hasNext;
      _loadingCount--;
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() async {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && _hasNext) {
        await _fetchTags(pageIndex: _pageIndex + 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _tags.clear();
          _pageIndex = 0;
        });
        await _fetchTags();
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _tags.length + (_loadingCount > 0 ? 1 : 0),
        itemBuilder: (context, index) {
          if (_loadingCount > 0) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final tag = _tags[index];
          return TagCard(
            tag: tag,
            onOpenDetails: () {
              widget.onClickTag(tag); // Use the passed callback here
            },
          );
        },
      ),
    );
  }
}
