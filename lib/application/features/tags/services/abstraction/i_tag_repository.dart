import 'package:whph/persistence/shared/repositories/abstraction/i_repository.dart';
import 'package:whph/domain/features/tags/tag.dart';

abstract class ITagRepository extends IRepository<Tag, String> {}
