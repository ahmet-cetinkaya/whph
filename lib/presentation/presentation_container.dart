import 'package:mediatr/mediatr.dart';
import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/core/acore/sounds/abstraction/sound_player/i_sound_player.dart';
import 'package:whph/infrastructure/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/presentation/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/features/habits/services/habits_service.dart';
import 'package:whph/presentation/features/notes/services/notes_service.dart';
import 'package:whph/presentation/features/notifications/services/reminder_service.dart';
import 'package:whph/presentation/features/tags/services/tags_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_reminder_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/services/json_notification_payload_handler.dart';
import 'package:whph/presentation/shared/services/translation_service.dart';
import 'package:whph/presentation/shared/utils/audio_player_sound_player.dart';
import 'package:whph/presentation/features/tasks/services/tasks_service.dart';
import 'package:whph/main.dart' show navigatorKey;

void registerPresentation(IContainer container) {
  // Register services
  container.registerSingleton<AppUsagesService>((_) => AppUsagesService());
  container.registerSingleton<HabitsService>((_) => HabitsService());
  container.registerSingleton<NotesService>((_) => NotesService());
  container.registerSingleton<TasksService>((_) => TasksService());
  container.registerSingleton<TagsService>((_) => TagsService());
  container.registerSingleton<ISoundPlayer>((_) => AudioPlayerSoundPlayer());
  container.registerSingleton<ITranslationService>((_) => TranslationService());
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
