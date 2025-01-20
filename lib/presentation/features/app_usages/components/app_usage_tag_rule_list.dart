import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/queries/get_list_app_usage_tag_rules_query.dart';
import 'package:whph/application/features/app_usages/commands/delete_app_usage_tag_rule_command.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';

class AppUsageTagRuleList extends StatefulWidget {
  final Mediator mediator;
  final Function(String id)? onRuleSelected;
  final List<String>? filterByTags;
  final bool? filterByActive;

  const AppUsageTagRuleList({
    super.key,
    required this.mediator,
    this.onRuleSelected,
    this.filterByTags,
    this.filterByActive,
  });

  @override
  State<AppUsageTagRuleList> createState() => _AppUsageTagRuleListState();
}

class _AppUsageTagRuleListState extends State<AppUsageTagRuleList> {
  GetListAppUsageTagRulesQueryResponse? _rules;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  @override
  void didUpdateWidget(AppUsageTagRuleList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterByTags != widget.filterByTags || oldWidget.filterByActive != widget.filterByActive) {
      _loadRules();
    }
  }

  Future<void> _loadRules() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final query = GetListAppUsageTagRulesQuery(
        pageIndex: 0,
        pageSize: 100,
        filterByTags: widget.filterByTags,
        filterByActive: widget.filterByActive,
      );

      _rules = await widget.mediator.send(query);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_rules == null || _rules!.items.isEmpty) {
      return const Center(
        child: Text(
          'No rules found',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _rules!.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final rule = _rules!.items[index];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    rule.tagName,
                    style: TextStyle(
                      fontSize: 11,
                      color: rule.tagColor != null ? Color(int.parse('FF${rule.tagColor}', radix: 16)) : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Pattern and Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Pattern: ',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              rule.pattern,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (rule.description != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            rule.description!,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),

                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () {
                    if (mounted) _delete(context, rule);
                  },
                  color: Colors.red,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.only(left: 8),
                  tooltip: 'Delete rule',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, AppUsageTagRuleListItem rule) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rule'),
        content: Text('Are you sure you want to delete the rule "${rule.pattern}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final command = DeleteAppUsageTagRuleCommand(id: rule.id);
        await widget.mediator.send(command);
        if (context.mounted) await _loadRules(); // Refresh list after successful deletion
      } catch (e, stackTrace) {
        if (context.mounted) ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace);
      }
    }
  }
}
