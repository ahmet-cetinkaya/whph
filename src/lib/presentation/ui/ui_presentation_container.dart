import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/infrastructure/shared/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/presentation/ui/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/features/notes/services/notes_service.dart';
import 'package:whph/presentation/ui/features/notifications/services/reminder_service.dart';
import 'package:whph/presentation/ui/features/tags/services/tags_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_confetti_animation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_reminder_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/confetti_animation_service.dart';
import 'package:whph/presentation/ui/shared/services/json_notification_payload_handler.dart';
import 'package:whph/presentation/ui/shared/services/theme_service.dart';
import 'package:whph/presentation/ui/shared/services/translation_service.dart';
import 'dart:io';
import 'package:whph/presentation/ui/shared/utils/audio_player_sound_player.dart';
import 'package:whph/infrastructure/windows/features/audio/windows_audio_player.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/features/about/services/abstraction/i_support_dialog_service.dart';
import 'package:whph/presentation/ui/features/about/services/support_dialog_service.dart';
import 'package:whph/main.dart' show navigatorKey;

void registerUIPresentation(IContainer container) {
  // Register services
  container.registerSingleton<AppUsagesService>((_) => AppUsagesService());
  container.registerSingleton<HabitsService>((_) => HabitsService());
  container.registerSingleton<NotesService>((_) => NotesService());
  container.registerSingleton<TasksService>((_) => TasksService(
        container.resolve<ITaskRecurrenceService>(),
        container.resolve<Mediator>(),
        container.resolve<ILogger>(),
      ));
  container.registerSingleton<TagsService>((_) => TagsService());
  container
      .registerSingleton<ISoundPlayer>((_) => Platform.isWindows ? WindowsAudioPlayer() : AudioPlayerSoundPlayer());
  container.registerSingleton<ITranslationService>((_) => TranslationService());
  container.registerSingleton<IThemeService>((_) => ThemeService(mediator: container.resolve<Mediator>()));
  container.registerSingleton<IConfettiAnimationService>((_) => ConfettiAnimationService());
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
