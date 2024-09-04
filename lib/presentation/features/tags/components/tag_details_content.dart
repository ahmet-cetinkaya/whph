import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/commands/add_tag_tag_command.dart';
import 'package:whph/application/features/tags/commands/remove_tag_tag_command.dart';
import 'package:whph/application/features/tags/queries/get_list_tag_tags_query.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/application/features/tags/queries/get_tag_query.dart';
import 'package:whph/main.dart';

class TagDetailsContent extends StatefulWidget {
  final int tagId;

  const TagDetailsContent({super.key, required this.tagId});

  @override
  State<TagDetailsContent> createState() => _TagDetailsContentState();
}

class _TagDetailsContentState extends State<TagDetailsContent> {
  final Mediator mediator = container.resolve<Mediator>();

  GetTagQueryResponse? tag;
  GetListTagsQueryResponse? tags;
  GetListTagTagsQueryResponse? tagTags;

  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTag();
    _fetchTags();
    _fetchTagTags();
  }

  Future<void> _fetchTag() async {
    var query = GetTagQuery(id: widget.tagId);
    var response = await mediator.send<GetTagQuery, GetTagQueryResponse>(query);
    setState(() {
      tag = response;
      _nameController.text = tag?.name ?? '';
    });
  }

  Future<void> _fetchTags() async {
    var query = GetListTagsQuery(pageIndex: 0, pageSize: 100); //TODO: Add lazy loading
    var response = await mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);
    setState(() {
      tags = response;
    });
  }

  Future<void> _fetchTagTags() async {
    var query = GetListTagTagsQuery(primaryTagId: widget.tagId, pageIndex: 0, pageSize: 100); //TODO: Add lazy loading
    var response = await mediator.send<GetListTagTagsQuery, GetListTagTagsQueryResponse>(query);
    setState(() {
      tagTags = response;
    });
  }

  Future<void> _addTagTag(int secondaryTagId) async {
    var command = AddTagTagCommand(primaryTagId: tag!.id, secondaryTagId: secondaryTagId);
    await mediator.send(command);
    _fetchTagTags();
  }

  Future<void> _removeTagTag(int id) async {
    var command = RemoveTagTagCommand(id: id);
    await mediator.send(command);
    _fetchTagTags();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: tag == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tags'),
                DropdownButton<int>(
                  onChanged: (value) {
                    if (value != null) {
                      _addTagTag(value);
                    }
                  },
                  items: tags?.items
                          .where((e) => e.id != tag!.id)
                          .map((e) => DropdownMenuItem<int>(
                                value: e.id,
                                child: Text(e.name),
                              ))
                          .toList() ??
                      [],
                ),
                const SizedBox(height: 16.0),

                // List
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: tagTags?.items.length ?? 0,
                  itemBuilder: (context, index) {
                    var tagTag = tagTags!.items[index];
                    return ListTile(
                      title: Text(tagTag.secondaryTagName),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _removeTagTag(tagTag.id);
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
