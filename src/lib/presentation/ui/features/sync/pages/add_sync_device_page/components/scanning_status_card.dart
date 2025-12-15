import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Card widget showing the current scanning status and progress
class ScanningStatusCard extends StatelessWidget {
  final String? progress;

  const ScanningStatusCard({
    super.key,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sizeLarge,
        vertical: AppTheme.sizeMedium,
      ),
      child: Card(
        elevation: 0,
        color: AppTheme.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sizeMedium),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                ),
              ),
              const SizedBox(width: AppTheme.sizeMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translationService.translate(SyncTranslationKeys.scanningForDevices),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (progress != null)
                      Text(
                        progress!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
