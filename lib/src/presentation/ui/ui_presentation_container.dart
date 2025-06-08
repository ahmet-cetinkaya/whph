import 'package:mediatr/mediatr.dart';
import 'package:whph/corePackages/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/corePackages/acore/sounds/abstraction/sound_player/i_sound_player.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/src/infrastructure/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/src/presentation/ui/features/app_usages/services/app_usages_service.dart';
import 'package:whph/src/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/src/presentation/ui/features/notes/services/notes_service.dart';
import 'package:whph/src/presentation/ui/features/notifications/services/reminder_service.dart';
import 'package:whph/src/presentation/ui/features/tags/services/tags_service.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_reminder_service.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/services/json_notification_payload_handler.dart';
import 'package:whph/src/presentation/ui/shared/services/translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/audio_player_sound_player.dart';
import 'package:whph/src/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/src/presentation/ui/features/about/services/abstraction/i_support_dialog_service.dart';
import 'package:whph/src/presentation/ui/features/about/services/support_dialog_service.dart';
import 'package:whph/main.dart' show navigatorKey;

void registerUIPresentation(IContainer container) {
  // Register services
  container.registerSingleton<AppUsagesService>((_) => AppUsagesService());
  container.registerSingleton<HabitsService>((_) => HabitsService());
  container.registerSingleton<NotesService>((_) => NotesService());
  container.registerSingleton<TasksService>((_) => TasksService(
        container.resolve<ITaskRecurrenceService>(),
        container.resolve<Mediator>(),
      ));
  container.registerSingleton<TagsService>((_) => TagsService());
  container.registerSingleton<ISoundPlayer>((_) => AudioPlayerSoundPlayer());
  container.registerSingleton<ITranslationService>((_) => TranslationService());
  container.registerSingleton<ISupportDialogService>(
    (_) {
      final mediator = container.resolve<Mediator>();
      return SupportDialogService(mediator);
    },
  );
  container.registerSingleton<ReminderService>((_) => ReminderService(
        container.resolve<IReminderService>(),
        container.resolve<Mediator>(),
        container.resolve<TasksService>(),
        container.resolve<HabitsService>(),
        container.resolve<ITranslationService>(),
        container.resolve<INotificationPayloadHandler>(),
      ));
  container.registerSingleton<INotificationPayloadHandler>(
    (_) => JsonNotificationPayloadHandler(navigatorKey),
  );
}
