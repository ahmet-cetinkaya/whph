import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/commands/save_app_usage_command.dart';
import 'package:whph/application/features/app_usages/queries/get_app_usage_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/utils/error_helper.dart';

class AppUsageNameInputField extends StatefulWidget {
  final String id;

  const AppUsageNameInputField({
    super.key,
    required this.id,
  });

  @override
  State<AppUsageNameInputField> createState() => _AppUsageNameInputFieldState();
}

class _AppUsageNameInputFieldState extends State<AppUsageNameInputField> {
  final Mediator _mediator = container.resolve<Mediator>();

  GetAppUsageQueryResponse? _appUsage;
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    _getAppUsage();
    super.initState();
  }

  Future<void> _getAppUsage() async {
    var query = GetAppUsageQuery(id: widget.id);
    var response = await _mediator.send<GetAppUsageQuery, GetAppUsageQueryResponse>(query);
    if (mounted) {
      setState(() {
        _appUsage = response;
        _controller.text = _appUsage?.displayName ?? _appUsage?.name ?? '';
      });
    }
  }

  Future<void> _saveAppUsage(BuildContext context) async {
    if (_appUsage == null) return;

    var command = SaveAppUsageCommand(
      id: widget.id,
      displayName: _appUsage!.name != _controller.text ? _controller.text : null,
      name: _appUsage!.name,
      color: _appUsage!.color,
    );

    try {
      await _mediator.send<SaveAppUsageCommand, SaveAppUsageCommandResponse>(command);
    } catch (e) {
      if (context.mounted) {
        ErrorHelper.showError(context, e);
      }
    }
  }

  void _onChange() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() {
        if (_appUsage != null) {
          _appUsage!.displayName = _controller.text;
        }
      });
      await _saveAppUsage(context);
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
      onChanged: (_) => _onChange(),
    );
  }
}
