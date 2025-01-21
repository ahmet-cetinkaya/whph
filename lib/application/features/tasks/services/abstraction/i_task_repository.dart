import 'package:whph/application/shared/services/i_repository.dart';
import 'package:whph/domain/features/tasks/task.dart';

abstract class ITaskRepository extends IRepository<Task, String> {}
