import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_tag_rule_form.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_tag_rule_list.dart';
import 'package:whph/presentation/features/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/shared/constants/navigation_items.dart';

class AppUsageTagRulesPage extends StatefulWidget {
  static const String route = '/app-usages/tag-rules';

  const AppUsageTagRulesPage({super.key});

  @override
  State<AppUsageTagRulesPage> createState() => _AppUsageTagRulesPageState();
}

class _AppUsageTagRulesPageState extends State<AppUsageTagRulesPage> {
  final Mediator _mediator = container.resolve<Mediator>();
  Key _listKey = UniqueKey();

  void _handleSaveRule() {
    setState(() {
      _listKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      appBarTitle: const Text('Tag Rules'),
      topNavItems: NavigationItems.topNavItems,
      bottomNavItems: NavigationItems.bottomNavItems,
      routes: {},
      defaultRoute: (context) => Container(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Form Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add New Rule',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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

                // Rules List Section
                const Text(
                  'Existing Rules',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
      ),
    );
  }
}
