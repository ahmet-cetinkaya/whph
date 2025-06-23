import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/app_usages/commands/add_app_usage_tag_rule_command.dart';
import 'package:whph/src/core/application/features/app_usages/commands/delete_app_usage_command.dart';
import 'package:whph/src/core/application/features/app_usages/commands/delete_app_usage_tag_rule_command.dart';
import 'package:whph/src/core/application/features/app_usages/commands/save_app_usage_command.dart';
import 'package:whph/src/core/application/features/app_usages/queries/get_app_usage_query.dart';
import 'package:whph/src/core/application/features/app_usages/queries/get_app_usage_statistics_query.dart';
import 'package:whph/src/core/application/features/app_usages/queries/get_list_app_usage_tag_rules_query.dart';
import 'package:whph/src/core/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/src/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/application/features/app_usages/commands/start_track_app_usages_command.dart';
import 'package:whph/src/core/application/features/app_usages/commands/stop_track_app_usages_command.dart';
import 'package:whph/src/core/application/features/app_usages/commands/add_app_usage_tag_command.dart';
import 'package:whph/src/core/application/features/app_usages/commands/remove_tag_tag_command.dart';
import 'package:whph/src/core/application/features/app_usages/queries/get_list_app_usage_tags_query.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_service.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/src/core/application/features/app_usages/commands/add_app_usage_ignore_rule_command.dart';
import 'package:whph/src/core/application/features/app_usages/commands/delete_app_usage_ignore_rule_command.dart';
import 'package:whph/src/core/application/features/app_usages/queries/get_list_app_usage_ignore_rules_query.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';

void registerAppUsagesFeature(
    IContainer container,
    Mediator mediator,
    IAppUsageService appUsageService,
    IAppUsageRepository appUsageRepository,
    ITagRepository tagRepository,
    IAppUsageTagRepository appUsageTagRepository,
    IAppUsageTagRuleRepository appUsageTagRuleRepository,
    IAppUsageTimeRecordRepository appUsageTimeRecordRepository,
    IAppUsageIgnoreRuleRepository appUsageIgnoreRuleRepository) {
  mediator
    ..registerHandler<StartTrackAppUsagesCommand, StartTrackAppUsagesCommandResponse,
        StartTrackAppUsagesCommandHandler>(
      () => StartTrackAppUsagesCommandHandler(appUsageService: appUsageService),
    )
    ..registerHandler<StopTrackAppUsagesCommand, StopTrackAppUsagesCommandResponse, StopTrackAppUsagesCommandHandler>(
      () => StopTrackAppUsagesCommandHandler(appUsageService),
    )
    ..registerHandler<GetListByTopAppUsagesQuery, GetListByTopAppUsagesQueryResponse,
        GetListByTopAppUsagesQueryHandler>(
      () => GetListByTopAppUsagesQueryHandler(
        timeRecordRepository: appUsageTimeRecordRepository,
      ),
    )
    ..registerHandler<AddAppUsageTagCommand, AddAppUsageTagCommandResponse, AddAppUsageTagCommandHandler>(
      () => AddAppUsageTagCommandHandler(appUsageTagRepository: appUsageTagRepository),
    )
    ..registerHandler<RemoveAppUsageTagCommand, RemoveAppUsageTagCommandResponse, RemoveAppUsageTagCommandHandler>(
      () => RemoveAppUsageTagCommandHandler(appUsageTagRepository: appUsageTagRepository),
    )
    ..registerHandler<GetListAppUsageTagsQuery, GetListAppUsageTagsQueryResponse, GetListAppUsageTagsQueryHandler>(
      () => GetListAppUsageTagsQueryHandler(
        tagRepository: tagRepository,
        appUsageTagRepository: appUsageTagRepository,
      ),
    )
    ..registerHandler<GetAppUsageQuery, GetAppUsageQueryResponse, GetAppUsageQueryHandler>(
      () => GetAppUsageQueryHandler(appUsageRepository: appUsageRepository),
    )
    ..registerHandler<SaveAppUsageCommand, SaveAppUsageCommandResponse, SaveAppUsageCommandHandler>(
      () => SaveAppUsageCommandHandler(appUsageRepository: appUsageRepository),
    )
    ..registerHandler<DeleteAppUsageCommand, DeleteAppUsageCommandResponse, DeleteAppUsageCommandHandler>(
      () => DeleteAppUsageCommandHandler(appUsageRepository: appUsageRepository),
    )
    ..registerHandler<AddAppUsageTagRuleCommand, AddAppUsageTagRuleCommandResponse, AddAppUsageTagRuleCommandHandler>(
      () => AddAppUsageTagRuleCommandHandler(repository: appUsageTagRuleRepository),
    )
    ..registerHandler<DeleteAppUsageTagRuleCommand, DeleteAppUsageTagRuleCommandResponse,
        DeleteAppUsageTagRuleCommandHandler>(
      () => DeleteAppUsageTagRuleCommandHandler(repository: appUsageTagRuleRepository),
    )
    ..registerHandler<GetListAppUsageTagRulesQuery, GetListAppUsageTagRulesQueryResponse,
        GetListAppUsageTagRulesQueryHandler>(
      () => GetListAppUsageTagRulesQueryHandler(
        appUsageRulesRepository: appUsageTagRuleRepository,
        tagRepository: tagRepository,
      ),
    )
    ..registerHandler<AddAppUsageIgnoreRuleCommand, AddAppUsageIgnoreRuleCommandResponse,
        AddAppUsageIgnoreRuleCommandHandler>(
      () => AddAppUsageIgnoreRuleCommandHandler(repository: appUsageIgnoreRuleRepository),
    )
    ..registerHandler<DeleteAppUsageIgnoreRuleCommand, DeleteAppUsageIgnoreRuleCommandResponse,
        DeleteAppUsageIgnoreRuleCommandHandler>(
      () => DeleteAppUsageIgnoreRuleCommandHandler(repository: appUsageIgnoreRuleRepository),
    )
    ..registerHandler<GetListAppUsageIgnoreRulesQuery, GetListAppUsageIgnoreRulesQueryResponse,
        GetListAppUsageIgnoreRulesQueryHandler>(
      () => GetListAppUsageIgnoreRulesQueryHandler(repository: appUsageIgnoreRuleRepository),
    )
    ..registerHandler<GetAppUsageStatisticsQuery, GetAppUsageStatisticsResponse, GetAppUsageStatisticsQueryHandler>(
      () => GetAppUsageStatisticsQueryHandler(appUsageTimeRecordRepository: appUsageTimeRecordRepository),
    );
}
