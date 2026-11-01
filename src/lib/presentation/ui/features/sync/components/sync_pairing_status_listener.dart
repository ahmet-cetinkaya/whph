import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_pairing_status_query.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/services/sync_pairing_flow.dart';

/// Watches for a pairing another device started with this one and shows the
/// same dialogs the starting device shows (code comparison). It does nothing
/// while this app already drives a pairing itself.
class SyncPairingStatusListener extends StatefulWidget {
  static const Duration defaultPollInterval = Duration(seconds: 1);

  final Widget child;
  final Mediator? mediator;
  final Duration pollInterval;

  /// Called with the final status after the listener resolved a pairing.
  final void Function(SyncPairingStatus status)? onFinished;

  const SyncPairingStatusListener({
    super.key,
    required this.child,
    this.mediator,
    this.pollInterval = defaultPollInterval,
    this.onFinished,
  });

  @override
  State<SyncPairingStatusListener> createState() => _SyncPairingStatusListenerState();
}

class _SyncPairingStatusListenerState extends State<SyncPairingStatusListener> {
  late final Mediator _mediator = widget.mediator ?? container.resolve<Mediator>();
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _poller = Timer.periodic(widget.pollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (SyncPairingFlow.isResolving) return;
    try {
      final status = await _mediator.send<GetSyncPairingStatusQuery, SyncPairingStatus>(GetSyncPairingStatusQuery());
      if (!mounted || !SyncPairingFlow.needsUser(status)) return;
      final finalStatus = await SyncPairingFlow(_mediator).resolve(context, status);
      widget.onFinished?.call(finalStatus);
    } catch (error) {
      Logger.error('SyncPairingStatusListener: following the pairing failed: ${error.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
