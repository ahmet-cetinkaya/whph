import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_statuses_query.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/domain/shared/constants/domain_log_components.dart';
import 'package:whph/main.dart';

/// Mixin that loads the full list of task statuses once on [initState] and
/// exposes them to the widget tree.  Used by widgets that need to resolve
/// status colors or display names from the complete status list.
mixin StatusLoaderMixin<T extends StatefulWidget> on State<T> {
  List<TaskStatusListItem>? statuses;

  @mustCallSuper
  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    try {
      final mediator = container.resolve<Mediator>();
      final response = await mediator.send<GetListTaskStatusesQuery, GetListTaskStatusesQueryResponse>(
        const GetListTaskStatusesQuery(),
      );
      if (mounted) {
        setState(() => statuses = response.items);
      }
    } catch (e, st) {
      Logger.error(
        'Failed to load task statuses in $T',
        error: e,
        stackTrace: st,
        component: DomainLogComponents.task,
      );
    }
  }
}
