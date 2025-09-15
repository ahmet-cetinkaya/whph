import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/commands/add_habit_record_command.dart';
import 'package:whph/core/application/features/habits/commands/add_habit_tag_command.dart';
import 'package:whph/core/application/features/habits/commands/add_habit_time_record_command.dart';
import 'package:whph/core/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/core/application/features/habits/commands/remove_habit_tag_command.dart';
import 'package:whph/core/application/features/habits/commands/update_habit_order_command.dart';
import 'package:whph/core/application/features/habits/commands/normalize_habit_orders_command.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_tags_query.dart';
import 'package:whph/core/application/features/habits/queries/get_total_duration_by_habit_id_query.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/core/application/features/habits/commands/delete_habit_command.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';

void registerHabitsFeature(
  IContainer container,
  Mediator mediator,
  IHabitRepository habitRepository,
  IHabitRecordRepository habitRecordRepository,
  IHabitTagsRepository habitTagRepository,
  IHabitTimeRecordRepository habitTimeRecordRepository,
  ITagRepository tagRepository,
) {
  mediator
    ..registerHandler<SaveHabitCommand, SaveHabitCommandResponse, SaveHabitCommandHandler>(
      () => SaveHabitCommandHandler(habitRepository: habitRepository),
    )
    ..registerHandler<DeleteHabitCommand, DeleteHabitCommandResponse, DeleteHabitCommandHandler>(
      () => DeleteHabitCommandHandler(
        habitRepository: habitRepository,
        habitTagsRepository: habitTagRepository,
        habitRecordRepository: habitRecordRepository,
      ),
    )
    ..registerHandler<GetListHabitsQuery, GetListHabitsQueryResponse, GetListHabitsQueryHandler>(
      () => GetListHabitsQueryHandler(
        habitRepository: habitRepository,
        habitTagRepository: habitTagRepository,
        tagRepository: tagRepository,
        habitRecordRepository: habitRecordRepository,
        habitTimeRecordRepository: habitTimeRecordRepository,
      ),
    )
    ..registerHandler<GetHabitQuery, GetHabitQueryResponse, GetHabitQueryHandler>(
      () => GetHabitQueryHandler(
        habitRepository: habitRepository,
        habitRecordRepository: habitRecordRepository,
      ),
    )
    ..registerHandler<AddHabitRecordCommand, AddHabitRecordCommandResponse, AddHabitRecordCommandHandler>(
      () => AddHabitRecordCommandHandler(habitRecordRepository: habitRecordRepository),
    )
    ..registerHandler<AddHabitTimeRecordCommand, AddHabitTimeRecordCommandResponse, AddHabitTimeRecordCommandHandler>(
      () => AddHabitTimeRecordCommandHandler(habitTimeRecordRepository: habitTimeRecordRepository),
    )
    ..registerHandler<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse, DeleteHabitRecordCommandHandler>(
      () => DeleteHabitRecordCommandHandler(habitRecordRepository: habitRecordRepository),
    )
    ..registerHandler<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse, GetListHabitRecordsQueryHandler>(
      () => GetListHabitRecordsQueryHandler(habitRecordRepository: habitRecordRepository),
    )
    ..registerHandler<GetListHabitTagsQuery, GetListHabitTagsQueryResponse, GetListHabitTagsQueryHandler>(
      () => GetListHabitTagsQueryHandler(
        tagRepository: tagRepository,
        habitTagRepository: habitTagRepository,
      ),
    )
    ..registerHandler<AddHabitTagCommand, AddHabitTagCommandResponse, AddHabitTagCommandHandler>(
      () => AddHabitTagCommandHandler(habitTagRepository: habitTagRepository),
    )
    ..registerHandler<RemoveHabitTagCommand, RemoveHabitTagCommandResponse, RemoveHabitTagCommandHandler>(
      () => RemoveHabitTagCommandHandler(habitTagRepository: habitTagRepository),
    )
    ..registerHandler<UpdateHabitOrderCommand, UpdateHabitOrderResponse, UpdateHabitOrderCommandHandler>(
      () => UpdateHabitOrderCommandHandler(habitRepository),
    )
    ..registerHandler<NormalizeHabitOrdersCommand, NormalizeHabitOrdersResponse, NormalizeHabitOrdersCommandHandler>(
      () => NormalizeHabitOrdersCommandHandler(habitRepository),
    )
    ..registerHandler<GetTotalDurationByHabitIdQuery, GetTotalDurationByHabitIdQueryResponse, GetTotalDurationByHabitIdQueryHandler>(
      () => GetTotalDurationByHabitIdQueryHandler(habitTimeRecordRepository: habitTimeRecordRepository),
    );
}
