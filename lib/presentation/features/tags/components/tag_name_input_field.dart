import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/application/features/tags/queries/get_tag_query.dart';
import 'package:whph/main.dart';

class TagNameInputField extends StatefulWidget {
  final String id;

  const TagNameInputField({
    super.key,
    required this.id,
  });

  @override
  State<TagNameInputField> createState() => _TagNameInputFieldState();
}

class _TagNameInputFieldState extends State<TagNameInputField> {
  final Mediator _mediator = container.resolve<Mediator>();
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _getTagName();
  }

  Future<void> _getTagName() async {
    var query = GetTagQuery(id: widget.id);
    var response = await _mediator.send<GetTagQuery, GetTagQueryResponse>(query);
    if (mounted) {
      setState(() {
        _controller.text = response.name;
      });
    }
  }

  void _saveTag(BuildContext context) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      var command = SaveTagCommand(
        id: widget.id,
        name: _controller.text,
      );
      try {
        await _mediator.send<SaveTagCommand, SaveTagCommandResponse>(command);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save tag')),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(border: InputBorder.none, filled: false),
      onChanged: (_) => _saveTag(context),
    );
  }
}
