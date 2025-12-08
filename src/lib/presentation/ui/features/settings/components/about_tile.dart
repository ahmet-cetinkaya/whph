import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/about/pages/about_page.dart';
import 'package:whph/presentation/ui/features/settings/components/settings_menu_tile.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/corePackages/acore/lib/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/corePackages/acore/lib/utils/responsive_dialog_helper.dart';
import 'package:whph/main.dart';

class AboutTile extends StatelessWidget {
  final ITranslationService _translationService = container.resolve<ITranslationService>();

  AboutTile({super.key});

  void _showAboutModal(BuildContext context) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: AboutPage(),
      size: DialogSize.large,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsMenuTile(
      icon: Icons.info,
      title: _translationService.translate(SettingsTranslationKeys.aboutTitle),
      onTap: () => _showAboutModal(context),
      isActive: true,
    );
  }
}
