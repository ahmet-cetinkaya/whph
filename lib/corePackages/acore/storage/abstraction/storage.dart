abstract class StorageAbstract {
  T? getValue<T>(String key);
  Future<void> setValue<T>(String key, T value);
  Future<void> removeValue(String key);
}
