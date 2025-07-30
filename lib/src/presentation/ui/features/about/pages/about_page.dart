import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/about/components/app_about.dart';
import 'package:whph/src/presentation/ui/features/about/constants/about_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class AboutPage extends StatefulWidget {
  static const String route = '/about';

  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final ITranslationService _translationService = container.resolve<ITranslationService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: Text(_translationService.translate(AboutTranslationKeys.aboutTitle)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          child: AppAbout(),
        ),
      ),
    );
  }
}
