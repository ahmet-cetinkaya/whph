import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/information_card.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Remembers that the user dismissed the one-time re-pair banner (FR-061).
class SyncRepairBannerPreference {
  static const String settingKey = 'sync_repair_banner_dismissed';

  final ISettingRepository _settingRepository;
  final Mediator _mediator;

  SyncRepairBannerPreference({required ISettingRepository settingRepository, required Mediator mediator})
      : _settingRepository = settingRepository,
        _mediator = mediator;

  Future<bool> isDismissed() async {
    final setting = await _settingRepository.getByKey(settingKey);
    return setting?.getValue<bool>() ?? false;
  }

  Future<void> dismiss() => _mediator.send<SaveSettingCommand, SaveSettingCommandResponse>(
        SaveSettingCommand(key: settingKey, value: true.toString(), valueType: SettingValueType.bool),
      );
}

/// Tells the user, once after the upgrade, that devices paired with the old
/// sync must pair again.
class SyncRepairBanner extends StatelessWidget {
  final VoidCallback onPair;
  final VoidCallback onDismiss;

  const SyncRepairBanner({super.key, required this.onPair, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return InformationCard.themed(
      context: context,
      icon: Icons.sync_problem,
      text: '${translationService.translate(SyncTranslationKeys.repairBannerTitle)}\n'
          '${translationService.translate(SyncTranslationKeys.repairBannerDescription)}',
      action: Wrap(
        children: [
          TextButton(
            onPressed: onDismiss,
            child: Text(translationService.translate(SyncTranslationKeys.repairBannerDismiss)),
          ),
          TextButton(
            onPressed: onPair,
            child: Text(translationService.translate(SyncTranslationKeys.syncStatusRepairAction)),
          ),
        ],
      ),
    );
  }
}
