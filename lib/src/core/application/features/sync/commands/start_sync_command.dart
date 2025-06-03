import 'package:flutter/foundation.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/sync/services/abstraction/i_sync_service.dart';

class StartSyncCommand implements IRequest<void> {}

class StartSyncCommandHandler implements IRequestHandler<StartSyncCommand, void> {
  final ISyncService _syncService;

  StartSyncCommandHandler(this._syncService);

  @override
  Future<void> call(StartSyncCommand request) async {
    if (kDebugMode) debugPrint('Starting sync service via command');
    _syncService.startSync();
    return;
  }
}
