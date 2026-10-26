import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:whph/core/application/features/sync/commands/cancel_pairing_command.dart';
import 'package:whph/core/application/features/sync/commands/create_pairing_invitation_command.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_pairing_status_query.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/features/sync/utils/sync_result_texts.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

enum PairingQrState { loading, showing, expired, used, paired, failed }

/// Owns the invitation shown as a QR code: its 5-minute countdown (FR-025) and
/// what became of it (scanned and paired, used up, expired).
class PairingQrController extends ChangeNotifier {
  static const Duration tickInterval = Duration(seconds: 1);

  final Mediator _mediator;
  final DateTime Function() _now;

  Timer? _ticker;
  DateTime? _expiresAt;
  bool _isDisposed = false;

  PairingQrState state = PairingQrState.loading;
  String? qrText;
  Duration remaining = Duration.zero;
  bool isPairingInProgress = false;
  String? errorCode;

  PairingQrController({required Mediator mediator, DateTime Function()? now})
      : _mediator = mediator,
        _now = now ?? DateTime.now;

  /// Shows a new invitation; the previous one stops working.
  Future<void> generate() async {
    _ticker?.cancel();
    state = PairingQrState.loading;
    errorCode = null;
    isPairingInProgress = false;
    notifyListeners();
    try {
      final response = await _mediator.send<CreatePairingInvitationCommand, CreatePairingInvitationCommandResponse>(
        CreatePairingInvitationCommand(),
      );
      if (_isDisposed) return;
      qrText = response.qrText;
      _expiresAt = response.invitation.expiresAt;
      remaining = _expiresAt!.difference(_now());
      state = PairingQrState.showing;
      _ticker = Timer.periodic(tickInterval, (_) => _tick());
    } catch (error) {
      Logger.error('PairingQrController: creating the invitation failed: $error');
      if (_isDisposed) return;
      state = PairingQrState.failed;
      errorCode = error is SyncPairingException ? error.code : SyncPairingErrorCode.refused;
    }
    notifyListeners();
  }

  Future<void> _tick() async {
    remaining = _expiresAt!.difference(_now());
    if (remaining <= Duration.zero) {
      _finish(PairingQrState.expired);
      return;
    }
    await _followPairing();
    if (!_isDisposed && state == PairingQrState.showing) notifyListeners();
  }

  Future<void> _followPairing() async {
    try {
      final status = await _mediator.send<GetSyncPairingStatusQuery, SyncPairingStatus>(GetSyncPairingStatusQuery());
      if (_isDisposed || state != PairingQrState.showing) return;
      isPairingInProgress = status.phase == SyncPairingPhase.connecting || status.phase == SyncPairingPhase.exchanging;
      if (status.phase == SyncPairingPhase.completed) _finish(PairingQrState.paired);
      if (status.phase == SyncPairingPhase.failed) _finishWithFailure(status.errorCode);
    } catch (error) {
      Logger.error('PairingQrController: reading the pairing status failed: $error');
    }
  }

  void _finishWithFailure(String? failureCode) {
    errorCode = failureCode;
    _finish(failureCode == SyncPairingErrorCode.codeExpiredOrUsed ? PairingQrState.used : PairingQrState.failed);
  }

  void _finish(PairingQrState finalState) {
    _ticker?.cancel();
    state = finalState;
    isPairingInProgress = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _ticker?.cancel();
    if (state == PairingQrState.showing) {
      unawaited(_mediator.send<CancelPairingCommand, void>(CancelPairingCommand()));
    }
    super.dispose();
  }
}

/// The QR code of a pairing invitation with its countdown and the states an
/// invitation ends in.
class PairingQrView extends StatefulWidget {
  final Mediator? mediator;
  final DateTime Function()? now;

  const PairingQrView({super.key, this.mediator, this.now});

  @override
  State<PairingQrView> createState() => _PairingQrViewState();
}

class _PairingQrViewState extends State<PairingQrView> {
  static const double _qrSize = 200;

  final _translationService = container.resolve<ITranslationService>();
  late final PairingQrController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PairingQrController(mediator: widget.mediator ?? container.resolve<Mediator>(), now: widget.now);
    _controller.generate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _countdownText() {
    final seconds = _controller.remaining.inSeconds.clamp(0, 59 * 60 + 59);
    final text = '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return _translationService.translate(SyncTranslationKeys.pairingQrExpiresIn, namedArgs: {'time': text});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: Column(
          children: [
            Text(
              _translationService.translate(SyncTranslationKeys.pairingQrTitle),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.sizeSmall),
            Text(
              _translationService.translate(SyncTranslationKeys.pairingQrDescription),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.sizeLarge),
            _buildBody(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return switch (_controller.state) {
      PairingQrState.loading => const SizedBox(
          height: _qrSize,
          child: Center(child: CircularProgressIndicator()),
        ),
      PairingQrState.showing => _buildQr(context),
      PairingQrState.paired => _buildMessage(context, Icons.check_circle, SyncTranslationKeys.pairingQrPaired),
      PairingQrState.expired =>
        _buildEnded(context, _translationService.translate(SyncTranslationKeys.pairingQrExpired)),
      PairingQrState.used => _buildEnded(context, _translationService.translate(SyncTranslationKeys.pairingQrUsed)),
      PairingQrState.failed =>
        _buildEnded(context, SyncResultTexts.pairingErrorText(_translationService, _controller.errorCode)),
    };
  }

  Widget _buildQr(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.sizeMedium),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: QrImageView(data: _controller.qrText!, size: _qrSize),
        ),
        const SizedBox(height: AppTheme.sizeMedium),
        Text(
          _controller.isPairingInProgress
              ? _translationService.translate(SyncTranslationKeys.pairingInProgress)
              : _countdownText(),
          key: const ValueKey('pairing-qr-status'),
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildMessage(BuildContext context, IconData icon, String key) {
    return Column(
      children: [
        Icon(icon, size: 64, color: AppTheme.successColor),
        const SizedBox(height: AppTheme.sizeSmall),
        Text(_translationService.translate(key), style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }

  Widget _buildEnded(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(Icons.qr_code_2, size: 64, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: AppTheme.sizeSmall),
        Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppTheme.sizeMedium),
        FilledButton.icon(
          onPressed: _controller.generate,
          icon: const Icon(Icons.refresh),
          label: Text(_translationService.translate(SyncTranslationKeys.pairingQrRegenerate)),
        ),
      ],
    );
  }
}
