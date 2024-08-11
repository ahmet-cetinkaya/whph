abstract class IContainer {
  IContainer get instance;

  T resolve<T>();

  void registerSingleton<T>(T Function(IContainer) factory);
}
