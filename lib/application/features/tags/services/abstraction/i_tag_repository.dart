import 'package:whph/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/domain/features/tags/tag.dart';

abstract class ITagRepository extends IRepository<Tag, String> {}
