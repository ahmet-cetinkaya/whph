import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/queries/get_list_app_usage_ignore_rules_query.dart';
import 'package:whph/application/features/app_usages/commands/delete_app_usage_ignore_rule_command.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/shared/components/load_more_button.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';

class AppUsageIgnoreRuleList extends StatefulWidget {
  final Mediator mediator;

  const AppUsageIgnoreRuleList({
    super.key,
    required this.mediator,
  });

  @override
  State<AppUsageIgnoreRuleList> createState() => _AppUsageIgnoreRuleListState();
}

class _AppUsageIgnoreRuleListState extends State<AppUsageIgnoreRuleList> {
  GetListAppUsageIgnoreRulesQueryResponse? _rules;
  bool _isLoading = false;
  final int _pageSize = 10;
  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules({int pageIndex = 0}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final query = GetListAppUsageIgnoreRulesQuery(
        pageIndex: pageIndex,
        pageSize: _pageSize,
      );

      final result =
          await widget.mediator.send<GetListAppUsageIgnoreRulesQuery, GetListAppUsageIgnoreRulesQueryResponse>(query);

      if (mounted) {
        setState(() {
          if (_rules == null || pageIndex == 0) {
            _rules = result;
          } else {
            _rules!.items.addAll(result.items);
            _rules!.pageIndex = result.pageIndex;
          }
        });
      }
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
          _translationService.translate(AppUsageTranslationKeys.noIgnoreRules),
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.disabledColor),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _rules!.items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final rule = _rules!.items[index];
            return Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                _translationService.translate(AppUsageTranslationKeys.patternLabel),
                                style: AppTheme.bodySmall.copyWith(color: Colors.grey),
                              ),
                              Expanded(
                                child: Text(
                                  rule.pattern,
                                  style: AppTheme.bodyMedium.copyWith(fontFamily: 'monospace'),
                                ),
                              ),
                            ],
                          ),
                          if (rule.description != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                rule.description!,
                                style: AppTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      child: IconButton(
                        icon: Icon(Icons.delete, size: AppTheme.iconSizeSmall),
                        onPressed: () => _delete(context, rule),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (_rules!.hasNext) LoadMoreButton(onPressed: () => _loadRules(pageIndex: _rules!.pageIndex + 1)),
      ],
    );
  }

  Future<void> _delete(BuildContext context, AppUsageIgnoreRuleListItem rule) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_translationService.translate(AppUsageTranslationKeys.deleteRuleTitle)),
        content: Text(_translationService
            .translate(AppUsageTranslationKeys.deleteRuleConfirm, namedArgs: {'pattern': rule.pattern})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: Text(_translationService.translate(SharedTranslationKeys.deleteButton)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final command = DeleteAppUsageIgnoreRuleCommand(id: rule.id);
        await widget.mediator.send<DeleteAppUsageIgnoreRuleCommand, DeleteAppUsageIgnoreRuleCommandResponse>(command);
        if (context.mounted) await _loadRules();
      } catch (e, stackTrace) {
        if (context.mounted) ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace);
      }
    }
  }
}
