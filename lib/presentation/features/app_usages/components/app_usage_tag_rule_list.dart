import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/queries/get_list_app_usage_tag_rules_query.dart';
import 'package:whph/application/features/app_usages/commands/delete_app_usage_tag_rule_command.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/shared/components/load_more_button.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

class AppUsageTagRuleList extends StatefulWidget {
  final Mediator mediator;
  final Function(String id)? onRuleSelected;
  final List<String>? filterByTags;

  const AppUsageTagRuleList({
    super.key,
    required this.mediator,
    this.onRuleSelected,
    this.filterByTags,
  });

  @override
  State<AppUsageTagRuleList> createState() => AppUsageTagRuleListState();
}

class AppUsageTagRuleListState extends State<AppUsageTagRuleList> {
  GetListAppUsageTagRulesQueryResponse? _rules;
  bool _isLoading = false;
  final int _pageSize = 10;
  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    await _loadRules(isRefresh: true);
  }

  Future<void> _loadRules({int pageIndex = 0, bool isRefresh = false}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final query = GetListAppUsageTagRulesQuery(
        pageIndex: pageIndex,
        pageSize: isRefresh ? _rules?.items.length ?? _pageSize : _pageSize,
        filterByTags: widget.filterByTags,
      );

      final result =
          await widget.mediator.send<GetListAppUsageTagRulesQuery, GetListAppUsageTagRulesQueryResponse>(query);

      if (mounted) {
        setState(() {
          if (_rules == null || pageIndex == 0) {
            _rules = result;
          } else {
            _rules!.items.addAll(result.items);
            _rules!.pageIndex = result.pageIndex;
          }
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace);
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
          _translationService.translate(SharedTranslationKeys.noItemsFoundMessage),
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
                padding: AppUsageUiConstants.cardPadding,
                child: Row(
                  children: [
                    // Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surface1,
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
                                "${_translationService.translate(AppUsageTranslationKeys.patternLabel)}:",
                                style: AppTheme.bodySmall.copyWith(color: Colors.grey),
                              ),
                              const SizedBox(width: AppTheme.sizeXSmall),
                              Expanded(
                                child: Text(
                                  rule.pattern,
                                  style: AppTheme.bodyMedium.copyWith(fontFamily: 'monospace', color: Colors.white),
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
                      icon: Icon(SharedUiConstants.deleteIcon, size: AppTheme.iconSizeSmall),
                      onPressed: () {
                        if (mounted) _delete(context, rule);
                      },
                      visualDensity: VisualDensity.compact,
                      tooltip: _translationService.translate(AppUsageTranslationKeys.deleteRuleTooltip),
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

  Future<void> _delete(BuildContext context, AppUsageTagRuleListItem rule) async {
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
        final command = DeleteAppUsageTagRuleCommand(id: rule.id);
        await widget.mediator.send<DeleteAppUsageTagRuleCommand, DeleteAppUsageTagRuleCommandResponse>(command);
        if (context.mounted) await refresh();
      } catch (e, stackTrace) {
        if (context.mounted) ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace);
      }
    }
  }
}
