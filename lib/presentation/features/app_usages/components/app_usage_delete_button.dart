import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/commands/delete_app_usage_command.dart';

import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/utils/error_helper.dart';

class AppUsageDeleteButton extends StatefulWidget {
  final String appUsageId;
  final VoidCallback? onDeleteSuccess;
  final Color? buttonColor;
  final Color? buttonBackgroundColor;

  const AppUsageDeleteButton({
    super.key,
    required this.appUsageId,
    this.onDeleteSuccess,
    this.buttonColor,
    this.buttonBackgroundColor,
  });

  @override
  State<AppUsageDeleteButton> createState() => _AppUsageDeleteButtonState();
}

class _AppUsageDeleteButtonState extends State<AppUsageDeleteButton> {
  final Mediator mediator = container.resolve<Mediator>();

  Future<void> _deleteAppUsage(BuildContext context) async {
    var command = DeleteAppUsageCommand(id: widget.appUsageId);
    try {
      await mediator.send(command);

      if (widget.onDeleteSuccess != null) {
        widget.onDeleteSuccess!();
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHelper.showError(context, e);
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this app usage?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) _deleteAppUsage(context);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _confirmDelete(context),
      icon: const Icon(Icons.delete),
      color: widget.buttonColor,
      style: ButtonStyle(
        backgroundColor:
            widget.buttonBackgroundColor != null ? WidgetStateProperty.all<Color>(widget.buttonBackgroundColor!) : null,
      ),
    );
  }
}
