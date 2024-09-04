import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/application/features/tags/queries/get_tag_query.dart';
import 'package:whph/main.dart';

class TagNameInputField extends StatefulWidget {
  final int id;

  const TagNameInputField({
    super.key,
    required this.id,
  });

  @override
  State<TagNameInputField> createState() => _TagNameInputFieldState();
}

class _TagNameInputFieldState extends State<TagNameInputField> {
  final Mediator mediator = container.resolve<Mediator>();

  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getTag();
  }

  Future<void> _getTag() async {
    var query = GetTagQuery(id: widget.id);
    var response = await mediator.send<GetTagQuery, GetTagQueryResponse>(query);
    setState(() {
      _controller.text = response.name;
    });
  }

  Future<void> _saveTag() async {
    var command = SaveTagCommand(
      id: widget.id,
      name: _controller.text,
    );
    await mediator.send<SaveTagCommand, SaveTagCommandResponse>(command);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(
        border: InputBorder.none,
      ),
      onChanged: (_) => _saveTag(),
    );
  }
}
