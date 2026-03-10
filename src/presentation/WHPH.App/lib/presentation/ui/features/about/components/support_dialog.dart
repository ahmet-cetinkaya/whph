import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/features/about/constants/about_translation_keys.dart';
import 'package:acore/acore.dart' hide Container;

class SupportDialog extends StatelessWidget {
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  SupportDialog({super.key});

  void _closeDialog(BuildContext context) {
    Navigator.pop(context);
  }

  void _openSupportUrl() {
    launchUrl(
      Uri.parse(AppInfo.supportUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.8,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _closeDialog(context),
                    ),
                  ],
                ),
                Stack(
                  children: [
                    Icon(
                      Icons.coffee,
                      size: AppTheme.iconSize2XLarge,
                      color: _themeService.primaryColor,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _themeService.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(AppTheme.size2XSmall),
                        child: Icon(
                          Icons.favorite,
                          size: AppTheme.iconSizeMedium,
                          color: ColorContrastHelper.getContrastingTextColor(_themeService.primaryColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sizeLarge),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _translationService.translate(
                      AboutTranslationKeys.supportMeTitle,
                      namedArgs: {'appName': AppInfo.name},
                    ),
                    style: AppTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sizeMedium),
            Text(
              _translationService.translate(
                AboutTranslationKeys.supportMeDescription,
                namedArgs: {'appName': AppInfo.name},
              ),
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.sizeLarge),
            FilledButton.icon(
              onPressed: _openSupportUrl,
              icon: const Icon(Icons.coffee),
              label: Text(
                _translationService.translate(AboutTranslationKeys.supportMeButtonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
