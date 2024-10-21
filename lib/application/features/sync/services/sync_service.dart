import 'dart:async';

import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/sync/commands/sync_command.dart';

import 'abstraction/i_sync_service.dart';

class SyncService implements ISyncService {
  final Mediator _mediator;

  Timer? _periodicTimer;

  SyncService(
    this._mediator,
  );

  @override
  Future<void> startSync() async {
    _periodicTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      var command = SyncCommand();
      await _mediator.send(command);
    });
  }

  @override
  void stopSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }
}
