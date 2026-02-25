import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/infrastructure/linux/constants/linux_app_constants.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/information_card.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class FlathubNoticeCard extends StatelessWidget {
  final ITranslationService translationService;
  final ValueListenable<bool> isTrackingActiveWindowWorking;

  const FlathubNoticeCard({
    super.key,
    required this.translationService,
    required this.isTrackingActiveWindowWorking,
  });

  @override
  Widget build(BuildContext context) {
    if (!LinuxAppConstants.isFlathub) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: isTrackingActiveWindowWorking,
      builder: (context, isTrackingWorking, child) {
        if (isTrackingWorking) return const SizedBox.shrink();

        return InformationCard.themed(
          context: context,
          icon: Icons.info_outline,
          text: translationService.translate(AppUsageTranslationKeys.flathubNotice),
          action: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                launchUrl(Uri.parse('${AppInfo.flatpakPackagingUrl}#installing-flatpak-from-release'));
              },
              child: Text(translationService.translate(SharedTranslationKeys.learnMore)),
            ),
          ),
        );
      },
    );
  }
}
