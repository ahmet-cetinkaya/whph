import 'package:whph/core/acore/repository/abstraction/i_repository.dart';
import 'package:whph/domain/features/tasks/task.dart';

abstract class ITaskRepository extends IRepository<Task, int> {}
