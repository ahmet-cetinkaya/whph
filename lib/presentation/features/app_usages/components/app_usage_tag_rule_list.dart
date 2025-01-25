import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/queries/get_list_app_usage_tag_rules_query.dart';
import 'package:whph/application/features/app_usages/commands/delete_app_usage_tag_rule_command.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_ui_constants.dart';

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
      return Center(
        child: Text(
          AppUsageUiConstants.noRulesFoundMessage,
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.disabledColor),
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
            padding: AppUsageUiConstants.cardPadding,
            child: Row(
              children: [
                // Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surface2,
                    borderRadius: BorderRadius.circular(AppUsageUiConstants.tagContainerBorderRadius),
                  ),
                  child: Text(
                    rule.tagName,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppUsageUiConstants.getTagColor(rule.tagColor),
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
                          Text(
                            'Pattern: ',
                            style: AppTheme.bodySmall.copyWith(color: Colors.grey),
                          ),
                          Expanded(
                            child: Text(
                              rule.pattern,
                              style: AppTheme.bodySmall.copyWith(fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                      if (rule.description != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            rule.description!,
                            style: AppTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),

                // Delete Button
                IconButton(
                  icon: Icon(SharedUiConstants.deleteIcon, size: AppUsageUiConstants.iconSize),
                  onPressed: () {
                    if (mounted) _delete(context, rule);
                  },
                  color: AppTheme.errorColor,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.only(left: 8),
                  tooltip: AppUsageUiConstants.deleteRuleTooltip,
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
        title: Text(AppUsageUiConstants.deleteRuleConfirmTitle),
        content: Text(AppUsageUiConstants.getDeleteRuleConfirmMessage(rule.pattern)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(SharedUiConstants.cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: Text(SharedUiConstants.deleteLabel),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final command = DeleteAppUsageTagRuleCommand(id: rule.id);
        await widget.mediator.send(command);
        if (context.mounted) await _loadRules();
      } catch (e, stackTrace) {
        if (context.mounted) ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace);
      }
    }
  }
}
