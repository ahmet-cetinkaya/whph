library core;

import '../../cqrs/abstraction/request_abstract.dart';

abstract class MediatorAbstract {
  Future<TResponse> send<TResponse>(RequestAbstract<TResponse> request);
}
