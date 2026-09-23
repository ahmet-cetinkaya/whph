abstract interface class IApplicationTransactionService {
  Future<T> run<T>(Future<T> Function() operation);
}

typedef ApplicationMutationGuard = Future<bool> Function();

final class MutationAuthorizationException implements Exception {
  const MutationAuthorizationException();
}

Future<void> ensureMutationAuthorized(
    ApplicationMutationGuard? authorize) async {
  if (authorize != null && !await authorize())
    throw const MutationAuthorizationException();
}
