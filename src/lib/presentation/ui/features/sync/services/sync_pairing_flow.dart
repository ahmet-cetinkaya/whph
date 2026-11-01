import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/commands/cancel_pairing_command.dart';
import 'package:whph/core/application/features/sync/commands/confirm_group_switch_command.dart';
import 'package:whph/core/application/features/sync/commands/confirm_pairing_code_command.dart';
import 'package:whph/core/application/features/sync/commands/pair_from_invitation_command.dart';
import 'package:whph/core/application/features/sync/commands/start_pairing_with_address_command.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/components/group_switch_dialog.dart';
import 'package:whph/presentation/ui/features/sync/components/pairing_code_dialog.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/features/sync/utils/sync_result_texts.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';

/// Drives a pairing to its end: starts it, asks the user at each step that
/// needs them (compare the code, confirm the group switch) and reports the
/// outcome. Both roles use it, so the dialogs look the same on both devices.
class SyncPairingFlow {
  final Mediator _mediator;

  /// One dialog sequence at a time: the page that started the pairing and the
  /// background listener must not both open the code dialog.
  static bool _isResolving = false;
  static bool get isResolving => _isResolving;

  SyncPairingFlow(this._mediator);

  Future<SyncPairingStatus> pairFromQr(BuildContext context, String qrText) async {
    final first = await _mediator.send<PairFromInvitationCommand, SyncPairingStatus>(
      PairFromInvitationCommand(qrText: qrText),
    );
    if (!context.mounted) return first;
    return resolve(context, first);
  }

  Future<SyncPairingStatus> pairWithAddress(BuildContext context, String address, {int? port}) async {
    final first = await _mediator.send<StartPairingWithAddressCommand, SyncPairingStatus>(
      StartPairingWithAddressCommand(address: address, port: port),
    );
    if (!context.mounted) return first;
    return resolve(context, first);
  }

  /// Follows [status] until it needs nothing more from the user.
  Future<SyncPairingStatus> resolve(BuildContext context, SyncPairingStatus status) async {
    if (_isResolving) return status;
    _isResolving = true;
    try {
      var current = status;
      while (context.mounted && needsUser(current)) {
        current = await _askUser(context, current);
      }
      return current;
    } finally {
      _isResolving = false;
    }
  }

  /// Whether the pairing waits for a decision of the user.
  static bool needsUser(SyncPairingStatus status) =>
      status.phase == SyncPairingPhase.comparingCodes || status.phase == SyncPairingPhase.awaitingGroupSwitch;

  Future<SyncPairingStatus> _askUser(BuildContext context, SyncPairingStatus status) {
    if (status.phase == SyncPairingPhase.comparingCodes) return _askToCompareCodes(context, status);
    return _askToSwitchGroup(context, status);
  }

  Future<SyncPairingStatus> _askToCompareCodes(BuildContext context, SyncPairingStatus status) async {
    final codesMatch = await PairingCodeDialog.show(context, code: status.code ?? '', peerName: status.peerName ?? '');
    if (codesMatch) return _mediator.send<ConfirmPairingCodeCommand, SyncPairingStatus>(ConfirmPairingCodeCommand());
    return _cancel(status, SyncPairingErrorCode.codesDiffer);
  }

  Future<SyncPairingStatus> _askToSwitchGroup(BuildContext context, SyncPairingStatus status) async {
    final confirmed = await GroupSwitchDialog.show(context, peerName: status.peerName ?? '');
    if (confirmed) return _mediator.send<ConfirmGroupSwitchCommand, SyncPairingStatus>(ConfirmGroupSwitchCommand());
    return _cancel(status, SyncPairingErrorCode.groupSwitchDeclined);
  }

  Future<SyncPairingStatus> _cancel(SyncPairingStatus status, String errorCode) async {
    await _mediator.send<CancelPairingCommand, void>(CancelPairingCommand());
    return SyncPairingStatus(
      phase: SyncPairingPhase.failed,
      role: status.role,
      peerName: status.peerName,
      errorCode: errorCode,
    );
  }

  /// Tells the user how a finished pairing ended; does nothing for a pairing
  /// that is still going on.
  static void showOutcome(BuildContext context, SyncPairingStatus status) {
    if (!status.isTerminal) return;
    final translationService = container.resolve<ITranslationService>();
    if (status.phase == SyncPairingPhase.completed) {
      OverlayNotificationHelper.showSuccess(
        context: context,
        message: translationService.translate(
          SyncTranslationKeys.pairingSuccess,
          namedArgs: {'device': status.peerName ?? ''},
        ),
      );
      return;
    }
    OverlayNotificationHelper.showError(
      context: context,
      message: SyncResultTexts.pairingErrorText(translationService, status.errorCode),
    );
  }
}
