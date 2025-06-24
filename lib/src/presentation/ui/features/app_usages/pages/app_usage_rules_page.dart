import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/app_usages/components/app_usage_ignore_rule_list.dart';
import 'package:whph/src/presentation/ui/features/app_usages/components/app_usage_tag_rule_form.dart';
import 'package:whph/src/presentation/ui/features/app_usages/components/app_usage_tag_rule_list.dart';
import 'package:whph/src/presentation/ui/shared/components/help_menu.dart';
import 'package:whph/src/presentation/ui/features/app_usages/components/app_usage_ignore_rule_form.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/components/border_fade_overlay.dart';

class AppUsageRulesPage extends StatefulWidget {
  static const String route = '/app-usages/rules';

  const AppUsageRulesPage({super.key});

  @override
  State<AppUsageRulesPage> createState() => _AppUsageRulesPageState();
}

class _AppUsageRulesPageState extends State<AppUsageRulesPage> with SingleTickerProviderStateMixin {
  final Mediator _mediator = container.resolve<Mediator>();
  final ITranslationService _translationService = container.resolve<ITranslationService>();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_translationService.translate(AppUsageTranslationKeys.rulesTitle)),
        actions: [
          HelpMenu(
            titleKey: AppUsageTranslationKeys.rulesHelpTitle,
            markdownContentKey: AppUsageTranslationKeys.rulesHelpContent,
          ),
          const SizedBox(width: AppTheme.sizeSmall),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: Column(
          children: [
            BorderFadeOverlay(
              fadeBorders: {FadeBorder.right},
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: _translationService.translate(AppUsageTranslationKeys.tagRules)),
                  Tab(text: _translationService.translate(AppUsageTranslationKeys.ignoreRules)),
                ],
                dividerColor: Colors.transparent,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tag Rules Tab
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.sizeLarge),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _translationService.translate(AppUsageTranslationKeys.addNewRule),
                                  style: AppTheme.headlineSmall,
                                ),
                                const SizedBox(height: AppTheme.sizeLarge),
                                AppUsageTagRuleForm(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.sizeXLarge),
                        Text(
                          _translationService.translate(AppUsageTranslationKeys.existingRules),
                          style: AppTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppTheme.sizeLarge),
                        AppUsageTagRuleList(
                          mediator: _mediator,
                        ),
                      ],
                    ),
                  ),

                  // Ignore Rules Tab
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.sizeLarge),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _translationService.translate(AppUsageTranslationKeys.addNewRule),
                                  style: AppTheme.headlineSmall,
                                ),
                                const SizedBox(height: AppTheme.sizeLarge),
                                AppUsageIgnoreRuleForm(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _translationService.translate(AppUsageTranslationKeys.existingRules),
                          style: AppTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        AppUsageIgnoreRuleList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
