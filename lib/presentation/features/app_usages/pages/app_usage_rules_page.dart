import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_ignore_rule_list.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_tag_rule_form.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_tag_rule_list.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_ignore_rule_form.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';

class AppUsageRulesPage extends StatefulWidget {
  static const String route = '/app-usages/rules';

  const AppUsageRulesPage({super.key});

  @override
  State<AppUsageRulesPage> createState() => _AppUsageRulesPageState();
}

class _AppUsageRulesPageState extends State<AppUsageRulesPage> with SingleTickerProviderStateMixin {
  final Mediator _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  Key _listKey = UniqueKey();
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

  void _handleSaveRule() {
    setState(() {
      _listKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      title: _translationService.translate(AppUsageTranslationKeys.rulesTitle),
      appBarActions: [
        HelpMenu(
          titleKey: AppUsageTranslationKeys.rulesHelpTitle,
          markdownContentKey: AppUsageTranslationKeys.rulesHelpContent,
        ),
        const SizedBox(width: 8), // Adjusted spacing
      ],
      builder: (context) => Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: _translationService.translate(AppUsageTranslationKeys.tagRules)),
              Tab(text: _translationService.translate(AppUsageTranslationKeys.ignoreRules)),
            ],
            dividerColor: Colors.transparent,
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
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _translationService.translate(AppUsageTranslationKeys.addNewRule),
                                style: AppTheme.headlineSmall,
                              ),
                              const SizedBox(height: 16),
                              AppUsageTagRuleForm(
                                onSave: _handleSaveRule,
                              ),
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
                      AppUsageTagRuleList(
                        key: _listKey,
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
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _translationService.translate(AppUsageTranslationKeys.addNewRule),
                                style: AppTheme.headlineSmall,
                              ),
                              const SizedBox(height: 16),
                              AppUsageIgnoreRuleForm(
                                onSave: _handleSaveRule,
                              ),
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
                      AppUsageIgnoreRuleList(
                        key: _listKey,
                        mediator: _mediator,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
