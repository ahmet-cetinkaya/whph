import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/api/api.dart';
import 'package:whph/application/application_container.dart';
import 'package:whph/application/features/app_usages/commands/start_track_app_usages_command.dart';
import 'package:whph/application/features/sync/commands/start_sync_command.dart';
import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/core/acore/dependency_injection/container.dart' as acore;
import 'package:whph/persistence/persistence_container.dart';
import 'package:whph/presentation/app.dart';
import 'main.mapper.g.dart' show initializeJsonMapper;

late final IContainer container;

void main() {
  container = acore.Container();
  initializeJsonMapper();

  registerPersistence(container);
  registerApplication(container);

  runBackgroundWorkers();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) startWebSocketServer();

  runApp(const App());
}

void runBackgroundWorkers() {
  var mediator = container.resolve<Mediator>();

  if (Platform.isAndroid || Platform.isIOS) {
    var startSyncCommand = StartSyncCommand();
    mediator.send(startSyncCommand);
  }

  var startTrackAppUsagesCommand = StartTrackAppUsagesCommand();
  mediator.send(startTrackAppUsagesCommand);
}
