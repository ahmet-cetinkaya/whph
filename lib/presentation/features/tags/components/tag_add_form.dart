import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/commands/save_tag_command.dart';

class TagForm extends StatefulWidget {
  final Mediator mediator;
  final VoidCallback onTagAdded;

  const TagForm({
    super.key,
    required this.mediator,
    required this.onTagAdded,
  });

  @override
  State<TagForm> createState() => _TagFormState();
}

class _TagFormState extends State<TagForm> {
  final TextEditingController _tagNameController = TextEditingController();

  Future<void> _addTag() async {
    final String name = _tagNameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    var command = SaveTagCommand(name: name);
    await widget.mediator.send<SaveTagCommand, SaveTagCommandResponse>(command);

    _tagNameController.clear();
    widget.onTagAdded();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _tagNameController,
              decoration: const InputDecoration(
                hintText: 'Enter tag title',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addTag,
          ),
        ],
      ),
    );
  }
}
