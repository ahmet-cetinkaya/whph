import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/application/features/tags/queries/get_tag_query.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';

class TagNameInputField extends StatefulWidget {
  final Mediator _mediator = container.resolve<Mediator>();

  final String id;

  TagNameInputField({
    super.key,
    required this.id,
  });

  @override
  State<TagNameInputField> createState() => _TagNameInputFieldState();
}

class _TagNameInputFieldState extends State<TagNameInputField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _getTagName();
  }

  Future<void> _getTagName() async {
    try {
      var query = GetTagQuery(id: widget.id);
      var response = await widget._mediator.send<GetTagQuery, GetTagQueryResponse>(query);
      if (mounted) {
        setState(() {
          _controller.text = response.name;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace, message: 'Failed to load tag name.');
      }
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
        await widget._mediator.send<SaveTagCommand, SaveTagCommandResponse>(command);
      } on BusinessException catch (e) {
        if (context.mounted) ErrorHelper.showError(context, e);
      } catch (e, stackTrace) {
        if (context.mounted) {
          ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
              message: 'Unexpected error occurred while saving tag.');
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
