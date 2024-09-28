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
  bool _hasNext = true;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 20; // Defines how many tags are loaded per page

  @override
  void initState() {
    super.initState();
    _fetchTags();
    _setupScrollListener();
  }

  Future<void> _fetchTags({int pageIndex = 0}) async {
    if (_isLoading || !_hasNext) return;

    setState(() {
      _isLoading = true;
    });

    try {
      var query = GetListTagsQuery(pageIndex: pageIndex, pageSize: _pageSize);
      var queryResponse = await widget.mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);

      setState(() {
        _tags = [..._tags, ...queryResponse.items];
        _pageIndex = pageIndex;
        _hasNext = queryResponse.hasNext;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && _hasNext && !_isLoading) {
        _fetchTags(pageIndex: _pageIndex + 1);
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
          _hasNext = true;
        });
        await _fetchTags();
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _tags.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _tags.length) {
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
            onOpenDetails: () => widget.onClickTag(tag),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
