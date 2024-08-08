import '../../cqrs/abstraction/request_abstract.dart';

abstract class RequestHandler<TRequest extends RequestAbstract<TResponse>, TResponse> {
  Future<TResponse> handle(TRequest request);
}
