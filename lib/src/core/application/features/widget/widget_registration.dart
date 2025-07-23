import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart';
import 'services/widget_service.dart';
import 'services/widget_update_service.dart';
import 'services/widget_event_handler.dart';

void registerWidgetFeature(IContainer container, Mediator mediator) {
  container.registerSingleton<WidgetService>((c) => WidgetService(mediator: mediator));
  container.registerSingleton<WidgetUpdateService>((c) => WidgetUpdateService(
        widgetService: c.resolve<WidgetService>(),
      ));
  container.registerSingleton<WidgetEventHandler>((c) => WidgetEventHandler(
        widgetService: c.resolve<WidgetService>(),
      ));
}
