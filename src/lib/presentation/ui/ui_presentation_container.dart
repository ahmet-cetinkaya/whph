import 'package:mediatr/mediatr.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_events.dart';
import 'package:whph/core/application/features/habits/services/i_habit_events.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_events.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_events.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_events.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_reminder_calculation_service.dart';
import 'package:whph/infrastructure/shared/features/notification/abstractions/i_notification_payload_handler.dart';
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
import 'package:whph/infrastructure/linux/features/theme/linux_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_tour_navigation_service.dart';
import 'package:whph/presentation/ui/shared/services/tour_navigation_service.dart';
import 'dart:io';
import 'package:whph/presentation/ui/shared/utils/audio_player_sound_player.dart';
import 'package:whph/infrastructure/windows/features/audio/windows_audio_player.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/features/tasks/services/task_calendar_service.dart';
import 'package:whph/presentation/ui/features/about/services/abstraction/i_support_dialog_service.dart';
import 'package:whph/presentation/ui/features/about/services/support_dialog_service.dart';
import 'package:whph/presentation/ui/features/about/services/abstraction/i_changelog_service.dart';
import 'package:whph/presentation/ui/features/about/services/changelog_service.dart';
import 'package:whph/presentation/ui/features/about/services/abstraction/i_changelog_dialog_service.dart';
import 'package:whph/presentation/ui/features/about/services/changelog_dialog_service.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_settings_effects.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_data_transfer_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_compression_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_restore_barrier.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_shutdown_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_single_instance_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_timer_session_service.dart';
import 'package:whph/core/application/shared/services/timer_session_service.dart';
import 'package:whph/main.dart' show navigatorKey;
import 'package:whph/presentation/ui/features/settings/services/settings_effects.dart';
import 'package:whph/presentation/ui/features/tasks/components/timer/timer_session_alarm_scheduler.dart';
import 'package:whph/presentation/ui/shared/services/application_shutdown_service.dart';
import 'package:whph/presentation/ui/shared/services/mcp_runtime_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_data_transfer_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_server_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_transfer_file_store.dart';
import 'package:whph/presentation/mcp/mcp_server_factory.dart';
import 'package:whph/presentation/mcp/mcp_tool_registry.dart';
import 'package:whph/presentation/mcp/mcp_tools.dart';
import 'package:whph/presentation/mcp/resources/mcp_resources.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/ui/shared/services/background_translation_service.dart';

void registerUIPresentation(IContainer container) {
  // Register services
  container.registerSingleton<AppUsagesService>((_) => AppUsagesService());
  container.registerSingleton<IAppUsageEvents>((_) => container.resolve<AppUsagesService>());
  container.registerSingleton<HabitsService>((_) => HabitsService());
  container.registerSingleton<IHabitEvents>((_) => container.resolve<HabitsService>());
  container.registerSingleton<NotesService>((_) => NotesService());
  container.registerSingleton<INoteEvents>((_) => container.resolve<NotesService>());
  container.registerSingleton<TasksService>((_) => TasksService(
        container.resolve<ITaskRecurrenceService>(),
        container.resolve<Mediator>(),
        container.resolve<ILogger>(),
      ));
  container.registerSingleton<ITaskEvents>((_) => container.resolve<TasksService>());
  container.registerSingleton<TagsService>((_) => TagsService());
  container.registerSingleton<ITagEvents>((_) => container.resolve<TagsService>());
  container.registerSingleton<TimeDataService>((_) => TimeDataService());
  container
      .registerSingleton<ISoundPlayer>((_) => Platform.isWindows ? WindowsAudioPlayer() : AudioPlayerSoundPlayer());
  container.registerSingleton<ISoundManagerService>((container) => SoundManagerService(
        soundPlayer: container.resolve<ISoundPlayer>(),
        settingRepository: container.resolve<ISettingRepository>(),
      ));
  container.registerSingleton<ITranslationService>((_) => TranslationService());
  if (Platform.isLinux) {
    container.registerSingleton<IThemeService>(
        (c) => LinuxThemeService(mediator: c.resolve<Mediator>(), logger: c.resolve<ILogger>()));
  } else {
    container.registerSingleton<IThemeService>(
        (c) => ThemeService(mediator: c.resolve<Mediator>(), logger: c.resolve<ILogger>()));
  }
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
  container.registerSingleton<ITimerSessionService>(
    (_) => TimerSessionService(
      durationWriter: MediatorTimerSessionDurationWriter(
        mediator: container.resolve<Mediator>(),
      ),
      alarmScheduler: TimerSessionAlarmScheduler(
        reminderService: container.resolve<IReminderService>(),
        translationService: container.resolve<ITranslationService>(),
      ),
    ),
  );
  container.registerSingleton<McpRuntimeService>(
    (_) => McpRuntimeService(
      accessService: container.resolve<IMcpAccessService>(),
      serverService: container.resolve<IMcpServerService>(),
      isAndroid: Platform.isAndroid,
    ),
  );
  container.registerSingleton<IApplicationShutdownService>(
    (_) => ApplicationShutdownService(
      timerSessionService: container.resolve<ITimerSessionService>(),
      mcpServerService: container.resolve<IMcpServerService>(),
      mcpAccessService: container.resolve<IMcpAccessService>(),
      singleInstanceService: PlatformUtils.isDesktop ? container.resolve<ISingleInstanceService>() : null,
    ),
  );
  container.registerSingleton<ISettingsEffects>(
    (_) => SettingsEffects(
      themeService: container.resolve<IThemeService>(),
      soundManagerService: container.resolve<ISoundManagerService>(),
      habitsService: container.resolve<HabitsService>(),
      reminderService: container.resolve<ReminderService>(),
      settingRepository: container.resolve<ISettingRepository>(),
      timerSessionService: container.resolve<ITimerSessionService>(),
      navigatorKey: navigatorKey,
    ),
  );
  container.registerSingleton<IMcpDataTransferService>(
    (_) => McpDataTransferService(
      mediator: container.resolve<Mediator>(),
      compressionService: container.resolve<ICompressionService>(),
      timerSessionService: container.resolve<ITimerSessionService>(),
      operationService: container.resolve<IMcpOperationService>(),
      fileStore: container.resolve<McpTransferFileStore>(),
      database: AppDatabase.instance(),
      reloadApplicationState: () => _reloadApplicationState(container),
    ),
  );
  container.registerSingleton<McpServerService>((_) {
    late final McpServerService service;
    service = McpServerService(
      accessService: container.resolve<IMcpAccessService>(),
      restoreBarrier: container.resolve<IRestoreBarrier>(),
      serverBuilder: (grant, authorize, runInvocation) {
        final registry = McpToolRegistry(
          tools: buildMcpTools(container, service),
          authorize: authorize,
          runInvocation: runInvocation,
        );
        final server = createMcpServer(
          serverInfo: const Implementation(
            name: AppInfo.shortName,
            version: AppInfo.version,
          ),
          tools: registry.discover(grant.scopes),
        );
        registerMcpResources(
          server: server,
          container: container,
          grant: grant,
          requestContext: service,
          toolRegistry: registry,
          authorize: authorize,
        );
        return server;
      },
    );
    return service;
  });
  container.registerSingleton<IMcpServerService>(
    (_) => container.resolve<McpServerService>(),
  );
  container.registerSingleton<IMcpRequestContext>(
    (_) => container.resolve<McpServerService>(),
  );
  container.registerSingleton<INotificationPayloadHandler>(
    (_) => JsonNotificationPayloadHandler(navigatorKey),
  );
  container.registerSingleton<ITourNavigationService>(
    (c) => TourNavigationServiceImpl(c.resolve<Mediator>()),
  );
  container.registerSingleton<TaskCalendarService>((c) => TaskCalendarService(c.resolve<Mediator>()));
}

Future<void> _reloadApplicationState(IContainer container) async {
  await container.resolve<IThemeService>().refreshTheme();
  await BackgroundTranslationService().initialize();
  await container.resolve<ReminderService>().refreshAllRemindersForLanguageChange();
  container.resolve<ISoundManagerService>().clearSettingsCache();
  notifyApplicationDataRestored(container);
}

void notifyApplicationDataRestored(IContainer container) {
  container.resolve<TasksService>().notifyRefresh();
  container.resolve<HabitsService>().notifyRefresh();
  container.resolve<NotesService>().notifyRefresh();
  container.resolve<TagsService>().notifyRefresh();
  container.resolve<AppUsagesService>().notifyRefresh();
  container.resolve<TimeDataService>().notifyTimeDataChanged();
  container.resolve<TaskCalendarService>().clearEvents();
}
