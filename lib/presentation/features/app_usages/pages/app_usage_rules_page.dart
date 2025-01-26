import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_tag_rule_form.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_tag_rule_list.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_ignore_rule_form.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

class AppUsageRulesPage extends StatefulWidget {
  static const String route = '/app-usages/rules';

  const AppUsageRulesPage({super.key});

  @override
  State<AppUsageRulesPage> createState() => _AppUsageRulesPageState();
}

class _AppUsageRulesPageState extends State<AppUsageRulesPage> with SingleTickerProviderStateMixin {
  final Mediator _mediator = container.resolve<Mediator>();
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

  void _showHelpModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'App Usage Rules Help',
                      style: AppTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '⚙️ App Usage Rules help you automate tag assignment and manage application tracking.',
                  style: AppTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  '🏷️ Tag Rules',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Automatic Tag Assignment:',
                  '  - Match apps by name patterns',
                  '  - Assign multiple tags',
                  '  - Track time automatically',
                  '• Rule Management:',
                  '  - Create new rules',
                  '  - Edit existing rules',
                  '  - Delete unused rules',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
                const SizedBox(height: 16),
                const Text(
                  '🚫 Ignore Rules',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Exclude Applications:',
                  '  - Skip unwanted apps',
                  '  - Ignore system processes',
                  '  - Filter background apps',
                  '• Pattern Matching:',
                  '  - Use wildcards',
                  '  - Match exact names',
                  '  - Case sensitivity options',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
                const SizedBox(height: 16),
                const Text(
                  '💡 Tips',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Use specific patterns for better matching',
                  '• Group similar applications under common tags',
                  '• Regularly review and update rules',
                  '• Test rules with different app names',
                  '• Use ignore rules for system utilities',
                  '• Combine rules for detailed tracking',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      title: 'App Usage Rules',
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: _showHelpModal,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(width: 2),
      ],
      builder: (context) => Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Tag Rules'),
              Tab(text: 'Ignore Rules'),
            ],
            dividerColor: Colors.transparent,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tag Rules Tab
                SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Add New Rule',
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
                        const Text(
                          'Existing Rules',
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
                ),

                // Ignore Rules Tab
                SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ignore Rules',
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
                      ],
                    ),
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
