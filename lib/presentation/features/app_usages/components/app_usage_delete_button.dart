import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/commands/delete_app_usage_command.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';

/// A button component that handles app usage deletion
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
  final Mediator _mediator = container.resolve<Mediator>();
  final AppUsagesService _appUsagesService = container.resolve<AppUsagesService>();
  final ITranslationService _translationService = container.resolve<ITranslationService>();
  bool _isDeleting = false;

  Future<void> confirmDelete(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
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

    if (confirmed == true && context.mounted) {
      await performDelete(context);
    }
  }

  Future<void> performDelete(BuildContext context) async {
    if (_isDeleting) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final command = DeleteAppUsageCommand(id: widget.appUsageId);
      final response = await _mediator.send<DeleteAppUsageCommand, DeleteAppUsageCommandResponse>(command);

      notifyDeletion(response.id);

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
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  void notifyDeletion(String id) {
    _appUsagesService.notifyAppUsageDeleted(id);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _isDeleting ? null : () => confirmDelete(context),
      icon: Icon(
        _isDeleting ? Icons.hourglass_empty : SharedUiConstants.deleteIcon,
      ),
      color: widget.buttonColor,
      style: ButtonStyle(
        backgroundColor:
            widget.buttonBackgroundColor != null ? WidgetStatePropertyAll<Color>(widget.buttonBackgroundColor!) : null,
      ),
      tooltip: _translationService.translate(SharedTranslationKeys.deleteButton),
    );
  }
}
