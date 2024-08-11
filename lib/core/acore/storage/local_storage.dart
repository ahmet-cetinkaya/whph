import '../storage/abstraction/storage.dart';
import 'package:get_storage/get_storage.dart';

class LocalStorage implements StorageAbstract {
  final GetStorage _storage = GetStorage();

  @override
  Future<void> setValue<T>(String key, T value) async {
    await _storage.write(key, value);
  }

  @override
  T? getValue<T>(String key) {
    return _storage.read<T>(key);
  }

  @override
  Future<void> removeValue(String key) async {
    await _storage.remove(key);
  }
}
