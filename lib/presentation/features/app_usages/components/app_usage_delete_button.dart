import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/commands/delete_app_usage_command.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';

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
    } on BusinessException catch (e) {
      if (context.mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (context.mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: 'Unexpected error occurred while deleting app usage.');
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppUsageUiConstants.deleteAppUsageConfirmTitle),
        content: Text(SharedUiConstants.confirmDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(SharedUiConstants.cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(SharedUiConstants.deleteLabel),
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
      icon: Icon(SharedUiConstants.deleteIcon),
      color: widget.buttonColor,
      style: ButtonStyle(
        backgroundColor:
            widget.buttonBackgroundColor != null ? WidgetStatePropertyAll<Color>(widget.buttonBackgroundColor!) : null,
      ),
    );
  }
}
