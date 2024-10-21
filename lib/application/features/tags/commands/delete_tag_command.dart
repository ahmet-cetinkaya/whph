import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/domain/features/tags/tag.dart';

class DeleteTagCommand implements IRequest<DeleteTagCommandResponse> {
  final String id;

  DeleteTagCommand({required this.id});
}

class DeleteTagCommandResponse {}

class DeleteTagCommandHandler implements IRequestHandler<DeleteTagCommand, DeleteTagCommandResponse> {
  final ITagRepository _tagRepository;

  DeleteTagCommandHandler({required ITagRepository tagRepository}) : _tagRepository = tagRepository;

  @override
  Future<DeleteTagCommandResponse> call(DeleteTagCommand request) async {
    Tag? tag = await _tagRepository.getById(request.id);
    if (tag == null) {
      throw Exception('Tag with id ${request.id} not found');
    }

    await _tagRepository.delete(tag);

    return DeleteTagCommandResponse();
  }
}
