import 'package:kiwi/kiwi.dart';

abstract class Injector {
  final KiwiContainer container = KiwiContainer();

  void setup();

  T resolve<T>() {
    return container.resolve<T>();
  }
}
