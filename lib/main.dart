import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/application_container.dart';
import 'package:whph/application/features/app_usages/commands/start_track_app_usages_command.dart';
import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/core/acore/dependency_injection/container.dart' as acore;
import 'package:whph/persistence/persistence_container.dart';
import 'package:whph/presentation/app.dart';

late final IContainer container;

void main() {
  container = acore.Container();
  registerPersistence(container);
  registerApplication(container);
  runBackgroundWorkers();

  runApp(const App());
}

void runBackgroundWorkers() {
  var mediator = container.resolve<Mediator>();

  var command = StartTrackAppUsagesCommand();
  mediator.send(command);
}
