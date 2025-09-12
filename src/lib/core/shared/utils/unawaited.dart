/// A function that can be used to explicitly ignore the result of a Future.
/// This is useful when you want to start a Future but don't want to await its result.
void unawaited(Future<void> future) {
  // This function intentionally does nothing.
  // Its purpose is to explicitly indicate that we're not awaiting the future.
}