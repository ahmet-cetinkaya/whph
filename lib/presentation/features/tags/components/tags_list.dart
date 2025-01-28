import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
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
  State<TagsList> createState() => _TagsListState();
}

class _TagsListState extends State<TagsList> {
  final _translationService = container.resolve<ITranslationService>();
  GetListTagsQueryResponse? _tags;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _getTags();
  }

  Future<void> _getTags({int pageIndex = 0}) async {
    try {
      var query = GetListTagsQuery(
        pageIndex: pageIndex,
        pageSize: _pageSize,
        filterByTags: widget.filterByTags,
        showArchived: widget.showArchived,
      );
      var result = await widget.mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);

      if (mounted) {
        setState(() {
          if (_tags == null) {
            _tags = result;
          } else {
            _tags!.items.addAll(result.items);
          }
        });
      }

      if (widget.onList != null) {
        widget.onList!(_tags!.items.length);
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: _translationService.translate(TagTranslationKeys.errorLoading));
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
