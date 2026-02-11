import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_reminder_calculation_service.dart';
import 'package:infrastructure_shared/features/notification/abstractions/i_notification_payload_handler.dart';
import 'package:whph/presentation/ui/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/features/notes/services/notes_service.dart';
import 'package:whph/presentation/ui/features/notifications/services/reminder_service.dart';
import 'package:whph/presentation/ui/features/tags/services/tags_service.dart';
import 'package:whph/presentation/ui/features/tags/services/time_data_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_confetti_animation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_reminder_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/presentation/ui/shared/services/confetti_animation_service.dart';
import 'package:whph/presentation/ui/shared/services/json_notification_payload_handler.dart';
import 'package:whph/presentation/ui/shared/services/sound_manager_service.dart';
import 'package:whph/presentation/ui/shared/services/theme_service/theme_service.dart';
import 'package:whph/presentation/ui/shared/services/translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_tour_navigation_service.dart';
import 'package:whph/presentation/ui/shared/services/tour_navigation_service.dart';
import 'dart:io';
import 'package:whph/presentation/ui/shared/utils/audio_player_sound_player.dart';
import 'package:infrastructure_windows/features/audio/windows_audio_player.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/features/about/services/abstraction/i_support_dialog_service.dart';
import 'package:whph/presentation/ui/features/about/services/support_dialog_service.dart';
import 'package:whph/presentation/ui/features/about/services/abstraction/i_changelog_service.dart';
import 'package:whph/presentation/ui/features/about/services/changelog_service.dart';
import 'package:whph/presentation/ui/features/about/services/abstraction/i_changelog_dialog_service.dart';
import 'package:whph/presentation/ui/features/about/services/changelog_dialog_service.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
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
  container.registerSingleton<TimeDataService>((_) => TimeDataService());
  container
      .registerSingleton<ISoundPlayer>((_) => Platform.isWindows ? WindowsAudioPlayer() : AudioPlayerSoundPlayer());
  container.registerSingleton<ISoundManagerService>((container) => SoundManagerService(
        soundPlayer: container.resolve<ISoundPlayer>(),
        settingRepository: container.resolve<ISettingRepository>(),
      ));
  container.registerSingleton<ITranslationService>((_) => TranslationService());
  container.registerSingleton<IThemeService>(
      (c) => ThemeService(mediator: c.resolve<Mediator>(), logger: c.resolve<ILogger>()));
  container.registerSingleton<IConfettiAnimationService>((_) => ConfettiAnimationService());
  container.registerSingleton<ISupportDialogService>(
    (_) {
      final mediator = container.resolve<Mediator>();
      return SupportDialogService(mediator);
    },
  );
  container.registerSingleton<IChangelogService>(
    (_) => ChangelogService(),
  );
  container.registerSingleton<IChangelogDialogService>(
    (_) {
      final mediator = container.resolve<Mediator>();
      final changelogService = container.resolve<IChangelogService>();
      final translationService = container.resolve<ITranslationService>();
      return ChangelogDialogService(mediator, changelogService, translationService);
    },
  );
  container.registerSingleton<ReminderService>((_) => ReminderService(
        container.resolve<IReminderService>(),
        container.resolve<Mediator>(),
        container.resolve<TasksService>(),
        container.resolve<HabitsService>(),
        container.resolve<ITranslationService>(),
        container.resolve<INotificationPayloadHandler>(),
        container.resolve<IReminderCalculationService>(),
      ));
  container.registerSingleton<INotificationPayloadHandler>(
    (_) => JsonNotificationPayloadHandler(navigatorKey),
  );
  container.registerSingleton<ITourNavigationService>(
    (c) => TourNavigationServiceImpl(c.resolve<Mediator>()),
  );
}
