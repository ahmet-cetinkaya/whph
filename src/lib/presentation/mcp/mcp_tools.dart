import 'dart:io';

import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_events.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_service.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/core/application/features/app_usages/services/app_usage_mcp_actions.dart';
import 'package:whph/core/application/features/habits/services/habit_actions.dart';
import 'package:whph/core/application/features/habits/services/i_habit_events.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_data_transfer_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_settings_effects.dart';
import 'package:whph/core/application/features/settings/services/settings_actions.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_network_interface_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:whph/core/application/features/sync/services/device_handshake_service.dart';
import 'package:whph/core/application/features/sync/services/sync_actions.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_events.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_status_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/application/features/tasks/services/mcp_task_actions.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_transaction_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_timer_session_service.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/tools/app_context_tools.dart';
import 'package:whph/presentation/mcp/tools/app_usage_tools.dart';
import 'package:whph/presentation/mcp/tools/data_transfer_tools.dart';
import 'package:whph/presentation/mcp/tools/habit_tools.dart';
import 'package:whph/presentation/mcp/tools/note_tools.dart';
import 'package:whph/presentation/mcp/tools/overview_tools.dart';
import 'package:whph/presentation/mcp/tools/settings_tools.dart';
import 'package:whph/presentation/mcp/tools/sync_tools.dart';
import 'package:whph/presentation/mcp/tools/tag_tools.dart';
import 'package:whph/presentation/mcp/tools/task_status_tools.dart';
import 'package:whph/presentation/mcp/tools/task_tools.dart';
import 'package:whph/presentation/mcp/tools/timer_tools.dart';

List<McpToolDefinition> buildMcpTools(
  IContainer container,
  IMcpRequestContext requestContext,
) {
  final mediator = container.resolve<Mediator>();
  final transactions = container.resolve<IApplicationTransactionService>();
  final taskActions = McpTaskActions(
    transactions: transactions,
    taskRepository: container.resolve<ITaskRepository>(),
    taskStatusRepository: container.resolve<ITaskStatusRepository>(),
    taskTagRepository: container.resolve<ITaskTagRepository>(),
    taskTimeRecordRepository: container.resolve<ITaskTimeRecordRepository>(),
    taskEvents: container.resolve<ITaskEvents>(),
    tagRepository: container.resolve<ITagRepository>(),
    recurrenceService: container.resolve<ITaskRecurrenceService>(),
    mediator: mediator,
  );
  final habitActions = HabitActions(
    transactions: transactions,
    habitRepository: container.resolve<IHabitRepository>(),
    habitRecordRepository: container.resolve<IHabitRecordRepository>(),
    habitTagsRepository: container.resolve<IHabitTagsRepository>(),
    habitTimeRecordRepository: container.resolve<IHabitTimeRecordRepository>(),
    tagRepository: container.resolve<ITagRepository>(),
    habitEvents: container.resolve<IHabitEvents>(),
  );
  final appUsageActions = AppUsageActions(
    transactionService: transactions,
    appUsageRepository: container.resolve<IAppUsageRepository>(),
    appUsageTagRepository: container.resolve<IAppUsageTagRepository>(),
    appUsageTimeRecordRepository: container.resolve<IAppUsageTimeRecordRepository>(),
    tagRuleRepository: container.resolve<IAppUsageTagRuleRepository>(),
    ignoreRuleRepository: container.resolve<IAppUsageIgnoreRuleRepository>(),
    appUsageService: container.resolve<IAppUsageService>(),
    appUsageEvents: container.resolve<IAppUsageEvents>(),
    tagRepository: container.resolve<ITagRepository>(),
    isTrackingSupported: Platform.isLinux || Platform.isWindows || Platform.isAndroid,
  );
  final settingsActions = SettingsActions(
    repository: container.resolve<ISettingRepository>(),
    transactions: transactions,
    effects: container.resolve<ISettingsEffects>(),
  );
  final syncActions = SyncActions(
    repository: container.resolve<ISyncDeviceRepository>(),
    transactions: transactions,
    syncService: container.resolve<ISyncService>(),
    deviceIds: container.resolve<IDeviceIdService>(),
    networkInterfaces: container.resolve<INetworkInterfaceService>(),
    handshake: container.resolve<DeviceHandshakeService>(),
  );
  Future<bool> authorize(_, Set<String> scopes) => requestContext.isAuthorized(scopes);

  return List<McpToolDefinition>.unmodifiable([
    ...buildTaskTools(
      mediator: mediator,
      actions: taskActions,
      authorizeBeforeCommit: authorize,
    ),
    ...buildTaskStatusTools(
      mediator: mediator,
      actions: taskActions,
      authorizeBeforeCommit: authorize,
    ),
    ...buildHabitTools(
      mediator: mediator,
      actions: habitActions,
      habitRepository: container.resolve<IHabitRepository>(),
      habitRecordRepository: container.resolve<IHabitRecordRepository>(),
      habitTimeRecordRepository: container.resolve<IHabitTimeRecordRepository>(),
      authorizeBeforeCommit: authorize,
    ),
    ...buildNoteTools(mediator, requestContext: requestContext),
    ...buildTagTools(mediator, requestContext: requestContext),
    ...buildTimerTools(
      timerSessionService: container.resolve<ITimerSessionService>(),
      mediator: mediator,
      authorize: authorize,
      selectNextMarathonTask: (selectedTaskId) => _selectNextMarathonTask(mediator, selectedTaskId),
    ),
    ...buildAppUsageTools(
      mediator: mediator,
      actions: appUsageActions,
      authorizeBeforeCommit: authorize,
    ),
    ...buildOverviewTools(
      mediator: mediator,
      authorizeSources: authorize,
    ),
    ...createSettingsTools(
      actions: settingsActions,
      requestContext: requestContext,
    ),
    ...createSyncTools(
      actions: syncActions,
      operations: container.resolve<IMcpOperationService>(),
      requestContext: requestContext,
    ),
    ...buildDataTransferTools(
      transferService: container.resolve<IMcpDataTransferService>(),
      operationService: container.resolve<IMcpOperationService>(),
      requestContext: requestContext,
    ),
    createAppContextTool(requestContext: requestContext),
  ]);
}

Future<String?> _selectNextMarathonTask(
  Mediator mediator,
  String? selectedTaskId,
) async {
  final response = await mediator.send<GetListTasksQuery, GetListTasksQueryResponse>(GetListTasksQuery(
    pageIndex: 0,
    pageSize: 2,
    filterByCompleted: false,
  ));
  return response.items.where((task) => task.id != selectedTaskId).firstOrNull?.id;
}
