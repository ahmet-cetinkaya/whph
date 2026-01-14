import 'package:flutter/material.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/notes/commands/save_note_command.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/features/notes/services/notes_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:whph/presentation/ui/shared/utils/context_manager.dart';
import 'package:whph/presentation/ui/shared/components/share_disambiguation_dialog.dart';
import 'package:whph/core/application/shared/constants/shared_translation_keys.dart';
import 'package:whph/infrastructure/android/features/share/android_share_service.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:acore/acore.dart' hide Container;

/// Service that handles creating tasks/notes from Android share intents
class ShareToCreateService {
  final IContainer _container;

  ShareToCreateService(this._container);

  /// Handles the share flow: shows disambiguation dialog and creates the selected item
  Future<bool> handleShareFlow({
    required String sharedText,
    String? sharedSubject,
    required BuildContext context,
    required ITranslationService translationService,
  }) async {
    final (title, description) = AndroidShareService.extractTitleFromText(sharedText);
    Logger.debug('ShareService: Extracted title: "$title", description: "$description"');

    return ShareDisambiguationDialog.show(
      context: context,
      sharedText: sharedText,
      sharedSubject: sharedSubject,
      translationService: translationService,
      onItemSelected: (type) => _createItem(
        type: type,
        title: title,
        description: description,
        subject: sharedSubject,
        text: sharedText,
        translationService: translationService,
      ),
    );
  }

  /// Creates an item (task or note) from shared text
  Future<bool> _createItem({
    required ShareItemType type,
    required String title,
    required String? description,
    required String? subject,
    required String text,
    required ITranslationService translationService,
  }) async {
    try {
      final mediator = _container.resolve<Mediator>();

      if (type == ShareItemType.task) {
        return await _createTask(
          mediator: mediator,
          title: title,
          description: description ?? subject,
          translationService: translationService,
        );
      }

      if (type == ShareItemType.note) {
        return await _createNote(
          mediator: mediator,
          title: title,
          content: description ?? subject ?? text,
          translationService: translationService,
        );
      }

      return false;
    } catch (e, stackTrace) {
      Logger.error('ShareService: Error creating item: $e', stackTrace: stackTrace);
      _showNotification(
        translationService: translationService,
        messageKey: SharedTranslationKeys.shareFailedToCreate,
        isSuccess: false,
      );
      return false;
    }
  }

  /// Creates a task from shared text
  Future<bool> _createTask({
    required Mediator mediator,
    required String title,
    required String? description,
    required ITranslationService translationService,
  }) async {
    final command = SaveTaskCommand(title: title, description: description);
    final response = await mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);

    // Notify tasks service
    final tasksService = _container.resolve<TasksService>();
    tasksService.notifyTaskCreated(response.id);

    Logger.debug('ShareService: Task created with ID: ${response.id}');
    _showNotification(
      translationService: translationService,
      messageKey: SharedTranslationKeys.shareTaskCreated,
      isSuccess: true,
    );
    return true;
  }

  /// Creates a note from shared text
  Future<bool> _createNote({
    required Mediator mediator,
    required String title,
    required String? content,
    required ITranslationService translationService,
  }) async {
    final command = SaveNoteCommand(title: title, content: content);
    final response = await mediator.send<SaveNoteCommand, SaveNoteCommandResponse>(command);

    // Notify notes service
    final notesService = _container.resolve<NotesService>();
    notesService.notifyNoteCreated(response.id);

    Logger.debug('ShareService: Note created with ID: ${response.id}');
    _showNotification(
      translationService: translationService,
      messageKey: SharedTranslationKeys.shareNoteCreated,
      isSuccess: true,
    );
    return true;
  }

  /// Shows a notification for share result
  void _showNotification({
    required ITranslationService translationService,
    required String messageKey,
    required bool isSuccess,
  }) {
    final notificationContext = ContextManager.context;
    if (notificationContext != null && notificationContext.mounted) {
      if (isSuccess) {
        OverlayNotificationHelper.showSuccess(
          context: notificationContext,
          message: translationService.translate(messageKey),
        );
      } else {
        OverlayNotificationHelper.showError(
          context: notificationContext,
          message: translationService.translate(messageKey),
        );
      }
    }
  }
}
