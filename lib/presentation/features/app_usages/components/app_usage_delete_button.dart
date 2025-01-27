import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/commands/delete_app_usage_command.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';

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
  final _translationService = container.resolve<ITranslationService>();

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
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(AppUsageTranslationKeys.deleteError),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_translationService.translate(AppUsageTranslationKeys.deleteConfirmTitle)),
        content: Text(_translationService.translate(SharedTranslationKeys.confirmDeleteMessage)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_translationService.translate(SharedTranslationKeys.deleteButton)),
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
