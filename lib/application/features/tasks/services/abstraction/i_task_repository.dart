import 'package:whph/persistence/shared/repositories/abstraction/i_repository.dart';
import 'package:whph/domain/features/tasks/task.dart';

abstract class ITaskRepository extends IRepository<Task, String> {}
