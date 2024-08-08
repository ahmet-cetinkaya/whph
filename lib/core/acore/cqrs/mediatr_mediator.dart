import '../cqrs/abstraction/mediator_abstract.dart';
import 'package:mediatr/mediatr.dart';

class MediatrMediator extends MediatorAbstract {
  final Mediator _mediator = Mediator(Pipeline());

  MediatrMediator(
    Function(Mediator) registerRequests,
  ) {
    registerRequests(_mediator);
  }

  @override
  Future<TResponse> send<TResponse>(request) {
    return _mediator.send(request as IRequest<TResponse>);
  }
}
