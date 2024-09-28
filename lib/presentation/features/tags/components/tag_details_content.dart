import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/commands/add_tag_tag_command.dart';
import 'package:whph/application/features/tags/commands/remove_tag_tag_command.dart';
import 'package:whph/application/features/tags/queries/get_list_tag_tags_query.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';

import 'package:whph/main.dart';

class TagDetailsContent extends StatefulWidget {
  final int tagId;

  const TagDetailsContent({super.key, required this.tagId});

  @override
  State<TagDetailsContent> createState() => _TagDetailsContentState();
}

class _TagDetailsContentState extends State<TagDetailsContent> {
  final Mediator mediator = container.resolve<Mediator>();
  List<TagListItem> _availableTags = [];
  List<TagTagListItem> _linkedTags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _fetchAvailableTags(),
        _fetchLinkedTags(),
      ]);
    } catch (e) {
      _handleError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAvailableTags() async {
    var query = GetListTagsQuery(pageIndex: 0, pageSize: 100);
    var response = await mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);
    setState(() {
      _availableTags = response.items.where((tag) => tag.id != widget.tagId).toList();
    });
  }

  Future<void> _fetchLinkedTags() async {
    var query = GetListTagTagsQuery(primaryTagId: widget.tagId, pageIndex: 0, pageSize: 100);
    var response = await mediator.send<GetListTagTagsQuery, GetListTagTagsQueryResponse>(query);
    setState(() {
      _linkedTags = response.items;
    });
  }

  Future<void> _addTag(int secondaryTagId) async {
    var command = AddTagTagCommand(primaryTagId: widget.tagId, secondaryTagId: secondaryTagId);
    await mediator.send(command);
    _fetchLinkedTags();
  }

  Future<void> _removeTag(int id) async {
    var command = RemoveTagTagCommand(id: id);
    await mediator.send(command);
    _fetchLinkedTags();
  }

  void _handleError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTagDropdown(),
                const SizedBox(height: 16.0),
                _buildLinkedTagsList(),
              ],
            ),
          );
  }

  Widget _buildTagDropdown() {
    return DropdownButton<int>(
      hint: const Text('Add a tag'),
      onChanged: (value) {
        if (value != null) {
          _addTag(value);
        }
      },
      items: _availableTags.map((tag) {
        return DropdownMenuItem<int>(
          value: tag.id,
          child: Text(tag.name),
        );
      }).toList(),
    );
  }

  Widget _buildLinkedTagsList() {
    if (_linkedTags.isEmpty) {
      return const Text('No tags linked yet.');
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _linkedTags.length,
      itemBuilder: (context, index) {
        var tagTag = _linkedTags[index];
        return ListTile(
          title: Text(tagTag.secondaryTagName),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _removeTag(tagTag.id),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
