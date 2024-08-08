import 'package:whph/core/acore/dependency_injection/injector.dart';
import 'package:whph/core/acore/mapper/abstraction/mapper.dart';
import 'package:whph/core/acore/mapper/mapper.dart';

class ApplicationInjector extends Injector {
  static final ApplicationInjector _instance = ApplicationInjector();
  static ApplicationInjector get instance => _instance;

  @override
  void setup() {
    super.container.registerSingleton<IMapper>((_) => CoreMapper());
  }
}
