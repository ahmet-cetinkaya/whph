import 'package:kiwi/kiwi.dart';
import 'abstraction/i_container.dart';

class Container implements IContainer {
  static final IContainer _instance = Container();
  @override
  IContainer get instance => _instance;

  final KiwiContainer _container = KiwiContainer();

  @override
  T resolve<T>() {
    return _container.resolve<T>();
  }

  @override
  void registerSingleton<T>(T Function(IContainer) factory) {
    _container.registerSingleton((_) => factory(this));
  }
}
